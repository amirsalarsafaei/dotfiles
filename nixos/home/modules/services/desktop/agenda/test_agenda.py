import contextlib
import datetime as dt
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import agenda


class AgendaTests(unittest.TestCase):
    def test_auth_keeps_credentials_out_of_argv_and_closes_file(self):
        with tempfile.TemporaryDirectory() as directory:
            client = Path(directory) / 'client.json'
            client.write_text(json.dumps({'installed': {
                'client_id': 'test-client', 'client_secret': 'private-test-secret',
            }}))
            descriptor = None

            def run(command, **kwargs):
                nonlocal descriptor
                self.assertEqual(command[-1], 'init')
                self.assertNotIn('private-test-secret', ' '.join(command))
                descriptor = kwargs['pass_fds'][0]
                self.assertEqual(command[1], f'@/proc/self/fd/{descriptor}')
                self.assertEqual(os.fstat(descriptor).st_mode & 0o777, 0o600)
                self.assertEqual(os.read(descriptor, 4096).decode(),
                                 '--client-id=test-client\n--client-secret=private-test-secret\n')
                self.assertEqual(kwargs['umask'], 0o077)
                return agenda.subprocess.CompletedProcess(command, 0)

            with patch.object(agenda, 'OAUTH_CLIENT', str(client)), \
                    patch.object(agenda.subprocess, 'run', side_effect=run), \
                    patch.object(agenda, 'update') as update:
                agenda.auth()
                update.assert_called_once()
            with self.assertRaises(OSError):
                os.fstat(descriptor)

    def test_auth_rejects_argument_file_injection(self):
        with tempfile.TemporaryDirectory() as directory:
            client = Path(directory) / 'client.json'
            client.write_text(json.dumps({'installed': {
                'client_id': 'test-client', 'client_secret': 'secret\n--config-folder=/tmp',
            }}))
            with patch.object(agenda, 'OAUTH_CLIENT', str(client)), \
                    patch.object(agenda.subprocess, 'run') as run:
                with self.assertRaises(SystemExit):
                    agenda.auth()
                run.assert_not_called()

    def test_tasks_scoped_to_daily_notes_and_dated(self):
        with tempfile.TemporaryDirectory() as directory:
            vault = Path(directory)
            (vault / 'project.md').write_text(
                '- [ ] Undated outside daily notes\n'
                '- [ ] Future 📅 2026-11-01\n'
                '* [ ] Today 📅 2026-10-30\n'
                '+ [ ] Overdue 📅 2026-10-29\n'
                '1. [ ] Invalid date 📅 2026-99-99\n'
                '- [x] Finished\n'
                '```markdown\n- [ ] Dated example 📅 2026-10-30\n```\n'
                '~~~\n- [ ] Another example 📅 2026-10-30\n~~~\n'
            )
            daily = vault / 'daily notes'
            daily.mkdir()
            (daily / '2026-10-30.md').write_text(
                '- [ ] Undated backlog\n'
                '- [ ] Scheduled 🛫 2026-10-31\n'
                '- [ ] ➕ 2026-10-01\n'
            )
            for excluded in ['Templates', '.obsidian']:
                (vault / excluded).mkdir()
                (vault / excluded / 'skip.md').write_text('- [ ] Skip me 📅 2026-10-30\n')
            with patch.object(agenda, 'VAULT', vault):
                tasks = agenda.fetch_tasks(dt.date(2026, 10, 30))
            self.assertEqual([task['title'] for task in tasks],
                             ['Overdue', 'Today', 'Undated backlog', 'Scheduled', 'Future'])
            self.assertEqual([task['path'] for task in tasks],
                             ['project.md', 'project.md', 'daily notes/2026-10-30.md',
                              'daily notes/2026-10-30.md', 'project.md'])
            self.assertEqual([task['line'] for task in tasks], [4, 3, 1, 2, 2])
            self.assertTrue(tasks[0]['overdue'])
            self.assertFalse(any(task['overdue'] for task in tasks[1:]))
            self.assertIsNone(tasks[2]['date'])
            self.assertEqual(tasks[3]['date'], '2026-10-31')
            self.assertEqual(tasks[-1]['date'], '2026-11-01')

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
