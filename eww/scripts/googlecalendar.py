import json
from datetime import datetime, timedelta

from gcsa.google_calendar import GoogleCalendar
from gcsa.serializers.event_serializer import EventSerializer
from google.oauth2 import service_account

credentials = service_account.Credentials.from_service_account_file(
    "credentials.json",
    scopes=[
        "https://www.googleapis.com/auth/calendar",
        "https://www.googleapis.com/auth/calendar.events",
        "https://www.googleapis.com/auth/calendar.events.readonly",
        "https://www.googleapis.com/auth/calendar.readonly",
        "https://www.googleapis.com/auth/calendar.settings.readonly",
    ],
)

calendar = GoogleCalendar("amirs.s.g.o@gmail.com", credentials=credentials)
today = datetime.now()
tommorow = today + timedelta(days=3)
tommorow = datetime(tommorow.year, tommorow.month, tommorow.day, 0, 0, 0)


def _date_sanitizer(date):
    if date.day == today.day:
        return f"Today {date.strftime('%H:%M')}"
    if (today + timedelta(days=1)).day == date.day:
        return f"Tommorow {date.strftime('%H:%M')}"
    return date.strftime("%d %B, %H:%M")


events = list(
    calendar.get_events(
        today - timedelta(minutes=5),
        tommorow + timedelta(minutes=5),
        single_events=True,
        order_by="startTime",
    )
)
events = [i for i in events if i.start is not None]
events_json = [EventSerializer.to_json(event) for event in events]
for event, event_json in zip(events, events_json):
    event_json["start"]["pretty_date"] = _date_sanitizer(event.start)
    event_json["end"]["pretty_date"] = _date_sanitizer(event.end)
print(json.dumps(events_json))
