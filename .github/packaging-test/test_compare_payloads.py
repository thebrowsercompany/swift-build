import unittest

from compare_payloads import compare


class PayloadComparisonTests(unittest.TestCase):
    def payload(self, variant='Asserts'):
        prefix = f'PFiles64/Swift/Toolchains/0.0.0+{variant}/usr/bin/'
        return {prefix + name: 'original' for name in ('swift-frontend.exe', 'FoundationMacros.dll', 'TestingMacros.dll', 'mimalloc.dll')}

    def test_identical_payloads_pass_for_both_variants(self):
        for variant in ['Asserts', 'NoAsserts']:
            with self.subTest(variant=variant):
                payload = self.payload(variant)
                self.assertTrue(compare(payload, payload, variant)['passed'])

    def test_missing_extra_or_changed_files_fail(self):
        baseline = self.payload()
        for path in baseline:
            candidate = dict(baseline)
            del candidate[path]
            self.assertFalse(compare(baseline, candidate, 'Asserts')['passed'])
        candidate = dict(baseline, unexpected='extra')
        self.assertFalse(compare(baseline, candidate, 'Asserts')['passed'])
        for path in baseline:
            if path.endswith('/mimalloc.dll'):
                continue
            candidate = dict(baseline)
            candidate[path] = 'different'
            self.assertFalse(compare(baseline, candidate, 'Asserts')['passed'])

    def test_rebuilt_mimalloc_difference_is_reported(self):
        baseline = self.payload()
        candidate = dict(baseline)
        path = next(path for path in baseline if path.endswith('/mimalloc.dll'))
        candidate[path] = 'rebuilt'
        result = compare(baseline, candidate, 'Asserts')
        self.assertTrue(result['passed'])
        self.assertEqual(result['rebuilt_mimalloc_changes'], [path])

    def test_wrong_variant_and_missing_macro_baseline_fail(self):
        payload = self.payload()
        self.assertFalse(compare(payload, payload, 'NoAsserts')['passed'])
        del payload[next(path for path in payload if path.endswith('/FoundationMacros.dll'))]
        self.assertFalse(compare(payload, payload, 'Asserts')['passed'])
        self.assertFalse(compare({}, {}, 'Asserts')['passed'])


if __name__ == '__main__':
    unittest.main()
