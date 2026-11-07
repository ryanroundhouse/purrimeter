"""External publication checkpoints: fake Apple, real frozen artifacts."""
import json
from pathlib import Path
import tempfile
import unittest

import app_store
from remote import digest


class Apple:
    def __init__(self, statuses, fail=None):
        self.statuses = iter(statuses)
        self.operations = []
        self.fail = fail

    def call(self, operation, **values):
        self.operations.append(operation)
        if operation == self.fail:
            raise RuntimeError('connection lost')
        if operation == 'status':
            return next(self.statuses)
        return {'submission_id': 'submission', 'build_id': 'build'}


VALID = {'build': {'id': 'build', 'state': 'VALID'}}
SUBMITTED = {**VALID, 'state': 'WAITING_FOR_REVIEW', 'selected_build': 'build', 'review_in_progress': True}


class AppStoreTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.record = Path(self.temp.name)
        (self.record / 'Purrimeter.ipa').write_bytes(b'exact signed IPA')
        self.state = {'version': '4.3.0', 'ios_sha256': digest(self.record / 'Purrimeter.ipa')}

    def publish(self, apple):
        return app_store.publish(self.record, self.state, 'credentials', self.record / 'store',
                                 client=apple, sleep=lambda _: None)

    def test_publishes_then_retries_without_external_mutations(self):
        apple = Apple([{}, VALID, SUBMITTED])
        self.publish(apple)
        self.assertEqual(apple.operations, ['status', 'upload', 'status', 'listing', 'submit', 'status'])
        self.assertTrue(self.state['app_store']['submitted_at'])
        self.publish(Apple([]))

    def test_tampered_ipa_never_touches_apple_even_after_success(self):
        self.state['app_store'] = {'submitted_at': 1}
        (self.record / 'Purrimeter.ipa').write_bytes(b'altered')
        apple = Apple([])
        with self.assertRaisesRegex(ValueError, 'altered bytes'):
            self.publish(apple)
        self.assertFalse(apple.operations)

    def test_unknown_upload_is_reconciled_without_duplicate_upload(self):
        apple = Apple([{}], fail='upload')
        with self.assertRaisesRegex(RuntimeError, 'connection lost'):
            self.publish(apple)
        saved = json.loads((self.record / 'state.json').read_text())
        self.assertEqual(saved['app_store']['sha256'], self.state['ios_sha256'])
        self.assertTrue(saved['app_store']['upload_started_at'])
        resumed = Apple([VALID, SUBMITTED])
        self.publish(resumed)
        self.assertNotIn('upload', resumed.operations)

    def test_ambiguous_upload_without_visible_build_requires_reconciliation(self):
        self.state['app_store'] = {'upload_started_at': 1, 'sha256': self.state['ios_sha256']}
        apple = Apple([{}])
        with self.assertRaisesRegex(ValueError, 'unknown'):
            self.publish(apple)
        self.assertEqual(apple.operations, ['status'])

    def test_foreign_build_cannot_be_claimed(self):
        with self.assertRaisesRegex(ValueError, 'without a local upload receipt'):
            self.publish(Apple([VALID]))

    def test_existing_review_blocks_new_release_before_upload(self):
        apple = Apple([{'review_in_progress': True}])
        with self.assertRaisesRegex(ValueError, 'still in review'):
            self.publish(apple)
        self.assertEqual(apple.operations, ['status'])

    def test_lost_submission_response_reconciles_selected_build(self):
        self.state['app_store'] = {'upload_started_at': 1, 'sha256': self.state['ios_sha256']}
        apple = Apple([SUBMITTED])
        self.publish(apple)
        self.assertEqual(apple.operations, ['status'])
        self.assertEqual(self.state['app_store']['build_id'], 'build')

    def test_wrong_selected_build_does_not_mark_success(self):
        self.state['app_store'] = {'upload_started_at': 1, 'sha256': self.state['ios_sha256']}
        with self.assertRaisesRegex(ValueError, 'different build'):
            self.publish(Apple([{**SUBMITTED, 'selected_build': 'foreign'}]))
        self.assertNotIn('submitted_at', self.state['app_store'])

    def test_failed_processing_never_updates_listing_or_submits(self):
        apple = Apple([{}, {'build': {'id': 'build', 'state': 'INVALID'}}])
        with self.assertRaisesRegex(ValueError, 'rejected build processing'):
            self.publish(apple)
        self.assertNotIn('listing', apple.operations)
        self.assertNotIn('submit', apple.operations)


if __name__ == '__main__':
    unittest.main()
