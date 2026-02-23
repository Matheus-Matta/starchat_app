// Assignment order types (maps to backend enum)
export const ROUND_ROBIN = 'round_robin';
export const BALANCED = 'balanced'; // kept for backwards-compat decoding only
export const EQUAL_DISTRIBUTION = 'equal_distribution';

// UI operation modes (what the user sees; 3 choices)
export const CUSTOM = 'custom';

// Assignment priority types
export const EARLIEST_CREATED = 'earliest_created';
export const LONGEST_WAITING = 'longest_waiting';

// Default values for fair distribution (Custom mode)
export const DEFAULT_FAIR_DISTRIBUTION_LIMIT = 100;
export const DEFAULT_FAIR_DISTRIBUTION_WINDOW = 3600;

// Default values for equal distribution
export const DEFAULT_EQUAL_DISTRIBUTION_WINDOW_HOURS = 24;
export const DEFAULT_EQUAL_DISTRIBUTION_BALANCE_THRESHOLD = 20;

// Options groupings
export const OPTIONS = {
  // Backend assignment_order options used inside Custom mode
  ORDER: [ROUND_ROBIN, EQUAL_DISTRIBUTION],
  PRIORITY: [EARLIEST_CREATED, LONGEST_WAITING],
  // Three UI modes shown to the user
  OPERATION_MODES: [ROUND_ROBIN, EQUAL_DISTRIBUTION, CUSTOM],
};
