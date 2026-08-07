import en from '../en';
import ptBR from '../pt_BR';

// Regression test for a bug where `BulkLabelActions.vue` (action="remove") referenced
// BULK_ACTION.LABELS.REMOVE_LABELS / REMOVE_SELECTED_LABELS, but those keys never
// existed in any locale file, so vue-i18n rendered the raw key instead of a translation.
describe('BULK_ACTION.LABELS translations', () => {
  it.each([
    ['en', en],
    ['pt_BR', ptBR],
  ])(
    '%s has non-empty REMOVE_LABELS and REMOVE_SELECTED_LABELS strings',
    (_locale, catalog) => {
      expect(catalog.BULK_ACTION.LABELS.REMOVE_LABELS).toEqual(
        expect.any(String)
      );
      expect(catalog.BULK_ACTION.LABELS.REMOVE_LABELS.length).toBeGreaterThan(
        0
      );

      expect(catalog.BULK_ACTION.LABELS.REMOVE_SELECTED_LABELS).toEqual(
        expect.any(String)
      );
      expect(
        catalog.BULK_ACTION.LABELS.REMOVE_SELECTED_LABELS.length
      ).toBeGreaterThan(0);
    }
  );
});
