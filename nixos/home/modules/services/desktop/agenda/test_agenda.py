import contextlib
import datetime as dt
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import agenda


class AgendaTests(unittest.TestCase):
    def test_all_open_tasks_and_source_locations(self):
        with tempfile.TemporaryDirectory() as directory:
            vault = Path(directory)
            (vault / 'tasks.md').write_text(
                '- [ ] Undated\n'
                '- [ ] Future 📅 2026-11-01\n'
                '* [ ] Today 📅 2026-10-30\n'
                '+ [ ] Overdue 📅 2026-10-29\n'
                '1. [ ] Invalid date 📅 2026-99-99\n'
                '- [x] Finished\n'
                '```markdown\n- [ ] Example\n```\n'
                '~~~\n- [ ] Another example\n~~~\n'
            )
            for excluded in ['Templates', '.obsidian']:
                (vault / excluded).mkdir()
                (vault / excluded / 'skip.md').write_text('- [ ] Skip me\n')
            with patch.object(agenda, 'VAULT', vault):
                tasks = agenda.fetch_tasks(dt.date(2026, 10, 30))
            self.assertEqual([task['title'] for task in tasks],
                             ['Overdue', 'Today', 'Invalid date', 'Undated', 'Future'])
            self.assertEqual([task['line'] for task in tasks], [4, 3, 5, 1, 2])
            self.assertTrue(tasks[0]['overdue'])
            self.assertFalse(any(task['overdue'] for task in tasks[1:]))
            self.assertIsNone(tasks[3]['date'])
            self.assertEqual(tasks[-1]['date'], '2026-11-01')
            self.assertTrue(all(task['path'] == 'tasks.md' for task in tasks))

    def test_review_slots_rotate_and_only_record_success(self):
        class Clock(dt.datetime):
            hour_value = 9

            @classmethod
            def now(cls):
                return cls(2026, 10, 30, cls.hour_value, 5)

        tasks = [{'title': f'Task {number}'} for number in range(7)]
        with tempfile.TemporaryDirectory() as directory, \
                patch.object(agenda, 'REVIEW_FILE', Path(directory) / 'review.json'), \
                patch.object(agenda.dt, 'datetime', Clock), \
                patch.object(agenda, 'send_notification', return_value=True) as notify:
            agenda.notify_task_review({'tasks': tasks})
            self.assertIn('□ Task 0', notify.call_args.args[1])
            self.assertEqual(notify.call_args.kwargs['expire'], 0)
            Clock.hour_value = 11
            agenda.notify_task_review({'tasks': tasks})
            self.assertEqual(notify.call_count, 1)
            Clock.hour_value = 12
            notify.return_value = False
            agenda.notify_task_review({'tasks': tasks})
            self.assertTrue(notify.call_args.args[1].startswith('□ Task 5\n□ Task 6\n□ Task 0'))
            notify.return_value = True
            agenda.notify_task_review({'tasks': tasks})
            self.assertEqual(notify.call_count, 3)
            agenda.notify_task_review({'tasks': tasks})
            self.assertEqual(notify.call_count, 3)
            Clock.hour_value = 22
            agenda.notify_task_review({'tasks': tasks})
            self.assertEqual(notify.call_count, 3)

    def test_empty_backlog_does_not_notify(self):
        with patch.object(agenda, 'send_notification') as notify:
            agenda.notify_task_review({'tasks': []})
            notify.assert_not_called()

    def test_bar_keeps_task_count_when_calendar_is_offline(self):
        data = agenda.empty_data(dt.date.today())
        data['calendar_status'] = 'stale'
        data['tasks'] = [{'title': 'Undated', 'date': None, 'overdue': False}]
        with patch.object(agenda, 'load_today', return_value=data), \
                patch.object(agenda, 'done_keys', return_value=[]), \
                contextlib.redirect_stdout(io.StringIO()) as output:
            agenda.waybar()
        self.assertTrue(json.loads(output.getvalue())['text'].startswith('1'))


if __name__ == '__main__':
    unittest.main()
