import datetime as dt
import os
import pickle
import subprocess
import time
from pathlib import Path
from typing import Literal
from urllib.parse import quote
from zoneinfo import ZoneInfo

from google.auth.transport.requests import AuthorizedSession
from mcp.server.fastmcp import FastMCP
from mcp.types import ToolAnnotations


API = "https://www.googleapis.com/calendar/v3"
DATA_DIR = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
OAUTH_FILE = DATA_DIR / "gcalcli/oauth"
BUSCTL = os.environ.get("AGENDA_BUSCTL", "busctl")
CALENDAR_TTL = 300
MAX_PAGE = 2500
SendUpdates = Literal["none", "all", "externalOnly"]
INSTRUCTIONS = """\
The user's Google Calendar. Only the user's own calendars are exposed: the primary calendar and
secondary calendars whose data owner is the user. Calendars other people share with the user are
hidden on purpose; do not try to reach them another way.

Times are ISO 8601. A bare date (YYYY-MM-DD) means an all-day event, and an all-day end date is
exclusive. A date-time without an offset is read in the calendar's time zone, which list_calendars
reports. Leave send_updates at "none" unless the user asks to notify attendees.
"""


class CalendarError(Exception):
    pass


def error_message(response):
    try:
        return response.json()["error"]["message"]
    except (ValueError, KeyError, TypeError):
        return response.text.strip() or response.reason


def refresh_agenda():
    try:
        subprocess.run(
            [
                BUSCTL,
                "--user",
                "call",
                "org.freedesktop.systemd1",
                "/org/freedesktop/systemd1",
                "org.freedesktop.systemd1.Manager",
                "StartUnit",
                "ss",
                "agenda-refresh.service",
                "replace",
            ],
            capture_output=True,
            check=False,
            timeout=10,
        )
    except (OSError, subprocess.TimeoutExpired):
        pass


def is_date(value):
    return len(value) == 10


def bound(value, zone):
    if is_date(value):
        moment = dt.datetime.combine(dt.date.fromisoformat(value), dt.time.min)
    else:
        moment = dt.datetime.fromisoformat(value)
    if moment.tzinfo is None:
        moment = moment.replace(tzinfo=ZoneInfo(zone))
    return moment.isoformat()


def event_time(value, zone):
    if is_date(value):
        return {"date": dt.date.fromisoformat(value).isoformat()}
    return {"dateTime": dt.datetime.fromisoformat(value).isoformat(), "timeZone": zone}


def start_moment(event, zone):
    start = event.get("start", {})
    if "dateTime" in start:
        return dt.datetime.fromisoformat(start["dateTime"])
    return dt.datetime.combine(dt.date.fromisoformat(start["date"]), dt.time.min, ZoneInfo(zone))


def event_body(
    zone,
    summary=None,
    start=None,
    end=None,
    description=None,
    location=None,
    attendees=None,
    recurrence=None,
    reminder_minutes=None,
):
    body = {
        "summary": summary,
        "description": description,
        "location": location,
        "recurrence": recurrence,
    }
    body = {key: value for key, value in body.items() if value is not None}
    if start is not None:
        body["start"] = event_time(start, zone)
    if end is not None:
        body["end"] = event_time(end, zone)
    if attendees is not None:
        body["attendees"] = [{"email": email} for email in attendees]
    if reminder_minutes is not None:
        body["reminders"] = {
            "useDefault": False,
            "overrides": [{"method": "popup", "minutes": minutes} for minutes in reminder_minutes],
        }
    return body


def summarize(event, calendar_id):
    start = event.get("start", {})
    end = event.get("end", {})
    people = event.get("attendees", [])
    me = next((person for person in people if person.get("self")), None)
    item = {
        "calendar_id": calendar_id,
        "event_id": event.get("id"),
        "summary": event.get("summary", "(No title)"),
        "start": start.get("dateTime") or start.get("date"),
        "end": end.get("dateTime") or end.get("date"),
        "all_day": "date" in start,
        "status": event.get("status"),
        "location": event.get("location"),
        "description": event.get("description"),
        "my_response": me.get("responseStatus") if me else None,
        "organizer": event.get("organizer", {}).get("email"),
        "attendees": [
            {"email": person.get("email"), "response": person.get("responseStatus")} for person in people
        ]
        or None,
        "recurring_event_id": event.get("recurringEventId"),
        "recurrence": event.get("recurrence"),
        "meet_link": event.get("hangoutLink"),
        "link": event.get("htmlLink"),
    }
    return {key: value for key, value in item.items() if value is not None}


class GoogleCalendar:
    def __init__(self):
        self.session = None
        self.primary = None
        self.owned = {}
        self.loaded_at = None

    def credentials(self):
        for _ in range(3):
            try:
                with OAUTH_FILE.open("rb") as handle:
                    return pickle.load(handle)
            except FileNotFoundError:
                raise CalendarError("Google Calendar is not connected; ask the user to run `agenda-os auth`") from None
            except (pickle.UnpicklingError, EOFError):
                time.sleep(0.5)
        raise CalendarError(f"Cannot read {OAUTH_FILE}; ask the user to run `agenda-os auth` again")

    def request(self, method, path, params=None, body=None):
        if self.session is None:
            self.session = AuthorizedSession(self.credentials())
        response = self.session.request(method, API + path, params=params, json=body, timeout=30)
        if response.status_code >= 400:
            raise CalendarError(f"Google Calendar returned {response.status_code}: {error_message(response)}")
        return response.json() if response.content else {}

    def paginate(self, path, params, limit=None):
        items = []
        token = None
        while limit is None or len(items) < limit:
            page = self.request("GET", path, params={**params, "pageToken": token} if token else params)
            items.extend(page.get("items", []))
            token = page.get("nextPageToken")
            if not token:
                break
        return items if limit is None else items[:limit]

    def calendars(self):
        if self.loaded_at is None or time.monotonic() - self.loaded_at > CALENDAR_TTL:
            entries = self.paginate("/users/me/calendarList", {})
            primary = next((entry for entry in entries if entry.get("primary")), None)
            if primary is None:
                raise CalendarError("The account has no primary calendar")
            self.primary = primary["id"]
            self.owned = {
                entry["id"]: entry
                for entry in entries
                if entry.get("primary") or entry.get("dataOwner") == self.primary
            }
            self.loaded_at = time.monotonic()
        return self.owned

    def resolve(self, calendar):
        owned = self.calendars()
        if not calendar or calendar == "primary":
            return self.primary
        if calendar in owned:
            return calendar
        matches = [
            key
            for key, entry in owned.items()
            if calendar in (entry.get("summary"), entry.get("summaryOverride"))
        ]
        if len(matches) == 1:
            return matches[0]
        raise CalendarError(f"{calendar!r} is not one of the user's calendars; call list_calendars")

    def zone(self, calendar_id):
        return self.calendars()[calendar_id].get("timeZone") or "UTC"

    def events_path(self, calendar_id, event_id=None):
        path = f"/calendars/{quote(calendar_id, safe='')}/events"
        return path if event_id is None else f"{path}/{quote(event_id, safe='')}"

    def list_events(self, start, end, calendar, query, include_declined, limit):
        chosen = self.resolve(calendar)
        targets = [chosen] if calendar else list(self.calendars())
        window = {"timeMin": bound(start, self.zone(chosen)), "timeMax": bound(end, self.zone(chosen))}
        found = []
        for calendar_id in targets:
            zone = self.zone(calendar_id)
            params = {
                **window,
                "singleEvents": "true",
                "orderBy": "startTime",
                "maxResults": min(limit, MAX_PAGE),
            }
            if query:
                params["q"] = query
            for event in self.paginate(self.events_path(calendar_id), params, limit):
                item = summarize(event, calendar_id)
                if include_declined or item.get("my_response") != "declined":
                    found.append((start_moment(event, zone), item))
        found.sort(key=lambda pair: pair[0])
        return [item for _, item in found[:limit]]

    def get_event(self, event_id, calendar):
        calendar_id = self.resolve(calendar)
        return summarize(self.request("GET", self.events_path(calendar_id, event_id)), calendar_id)

    def save_event(self, calendar, event_id, time_zone, send_updates, **fields):
        calendar_id = self.resolve(calendar)
        body = event_body(time_zone or self.zone(calendar_id), **fields)
        event = self.request(
            "POST" if event_id is None else "PATCH",
            self.events_path(calendar_id, event_id),
            params={"sendUpdates": send_updates},
            body=body,
        )
        refresh_agenda()
        return summarize(event, calendar_id)

    def delete_event(self, event_id, calendar, send_updates):
        calendar_id = self.resolve(calendar)
        self.request("DELETE", self.events_path(calendar_id, event_id), params={"sendUpdates": send_updates})
        refresh_agenda()
        return {"deleted": event_id, "calendar_id": calendar_id}


account = GoogleCalendar()
server = FastMCP("calendar", instructions=INSTRUCTIONS, log_level="WARNING")


@server.tool(
    description="List the user's own calendars with their id, name, access role and time zone.",
    annotations=ToolAnnotations(readOnlyHint=True),
)
def list_calendars() -> list[dict]:
    return [
        {
            "id": key,
            "name": entry.get("summaryOverride") or entry.get("summary"),
            "primary": bool(entry.get("primary")),
            "access_role": entry.get("accessRole"),
            "time_zone": entry.get("timeZone"),
        }
        for key, entry in account.calendars().items()
    ]


@server.tool(
    description=(
        "List events between start and end (ISO date or date-time, end exclusive), expanded into single "
        "occurrences and sorted by start. Searches every own calendar unless calendar (id or name) is given. "
        "query is Google's free-text search. Declined invitations are skipped unless include_declined is true."
    ),
    annotations=ToolAnnotations(readOnlyHint=True),
)
def list_events(
    start: str,
    end: str,
    calendar: str | None = None,
    query: str | None = None,
    include_declined: bool = False,
    limit: int = 250,
) -> list[dict]:
    return account.list_events(start, end, calendar, query, include_declined, max(1, limit))


@server.tool(
    description="Get one event by event_id from an own calendar (default primary).",
    annotations=ToolAnnotations(readOnlyHint=True),
)
def get_event(event_id: str, calendar: str | None = None) -> dict:
    return account.get_event(event_id, calendar)


@server.tool(
    description=(
        "Create an event on an own calendar (default primary). start and end are ISO dates for all-day events "
        "or date-times. recurrence takes RRULE lines such as RRULE:FREQ=WEEKLY;BYDAY=MO. reminder_minutes "
        "replaces the calendar's default popup reminders. Adding attendees and send_updates other than none "
        "emails other people."
    ),
    annotations=ToolAnnotations(readOnlyHint=False, destructiveHint=False),
)
def create_event(
    summary: str,
    start: str,
    end: str,
    calendar: str | None = None,
    description: str | None = None,
    location: str | None = None,
    time_zone: str | None = None,
    attendees: list[str] | None = None,
    recurrence: list[str] | None = None,
    reminder_minutes: list[int] | None = None,
    send_updates: SendUpdates = "none",
) -> dict:
    return account.save_event(
        calendar,
        None,
        time_zone,
        send_updates,
        summary=summary,
        start=start,
        end=end,
        description=description,
        location=location,
        attendees=attendees,
        recurrence=recurrence,
        reminder_minutes=reminder_minutes,
    )


@server.tool(
    description=(
        "Change fields of an event on an own calendar; omitted fields stay as they are. attendees replaces the "
        "whole list. An occurrence id changes one occurrence; a recurring_event_id changes the whole series."
    ),
    annotations=ToolAnnotations(readOnlyHint=False, destructiveHint=True),
)
def update_event(
    event_id: str,
    calendar: str | None = None,
    summary: str | None = None,
    start: str | None = None,
    end: str | None = None,
    description: str | None = None,
    location: str | None = None,
    time_zone: str | None = None,
    attendees: list[str] | None = None,
    recurrence: list[str] | None = None,
    reminder_minutes: list[int] | None = None,
    send_updates: SendUpdates = "none",
) -> dict:
    return account.save_event(
        calendar,
        event_id,
        time_zone,
        send_updates,
        summary=summary,
        start=start,
        end=end,
        description=description,
        location=location,
        attendees=attendees,
        recurrence=recurrence,
        reminder_minutes=reminder_minutes,
    )


@server.tool(
    description="Delete an event from an own calendar. A recurring_event_id deletes the whole series.",
    annotations=ToolAnnotations(readOnlyHint=False, destructiveHint=True),
)
def delete_event(event_id: str, calendar: str | None = None, send_updates: SendUpdates = "none") -> dict:
    return account.delete_event(event_id, calendar, send_updates)


if __name__ == "__main__":
    server.run()
