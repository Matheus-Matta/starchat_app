// Minimal Cosmos-compatible label suggestions composable
// Provides the interface expected by MessagesView and related components.
// Currently returns disabled flags and empty suggestions to avoid runtime errors
// until a full Cosmos implementation is wired.

import { computed } from 'vue';

export function useLabelSuggestions() {
  // Keep upstream-compatible names to avoid refactors in callers
  const captainTasksEnabled = computed(() => false);
  const isLabelSuggestionFeatureEnabled = computed(() => false);

  const getLabelSuggestions = async () => {
    return [];
  };

  return {
    captainTasksEnabled,
    isLabelSuggestionFeatureEnabled,
    getLabelSuggestions,
  };
}
