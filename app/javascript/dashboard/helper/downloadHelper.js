import fromUnixTime from 'date-fns/fromUnixTime';
import format from 'date-fns/format';
import * as XLSX from 'xlsx';

export const downloadCsvFile = (fileName, content) => {
  const contentType = 'data:text/csv;charset=utf-8;';
  const blob = new Blob([content], { type: contentType });
  const url = URL.createObjectURL(blob);

  const link = document.createElement('a');
  link.setAttribute('download', fileName);
  link.setAttribute('href', url);
  link.click();
  return link;
};

// Plain numeric strings (e.g. "42") read back as real numbers so they stay
// sortable/summable in Excel, same as before. Anything else (dates, IDs with
// leading zeros, formatted durations) stays exactly as the CSV wrote it.
const NUMERIC_CELL_REGEX = /^-?\d+(\.\d+)?$/;

// SheetJS auto-detects date-like strings (e.g. "2026-06-08") and converts them to
// Excel's serial date number, but does so using local-time math, shifting the value
// by the browser's UTC offset (e.g. it becomes 46180.875 instead of a clean integer).
// Reading with `raw: true` keeps every cell as the literal CSV text, avoiding that
// corruption; we then restore plain numbers ourselves so counts/metrics are unaffected.
export const downloadXlsFile = (fileName, csvContent) => {
  const wb = XLSX.read(csvContent, { type: 'string', raw: true });
  wb.SheetNames.forEach(sheetName => {
    const sheet = wb.Sheets[sheetName];
    Object.keys(sheet).forEach(cellRef => {
      if (cellRef.startsWith('!')) return;
      const cell = sheet[cellRef];
      if (cell.t === 's' && NUMERIC_CELL_REGEX.test(cell.v)) {
        cell.t = 'n';
        cell.v = Number(cell.v);
      }
    });
  });

  const xlsxFileName = fileName.replace(/\.csv$/, '.xlsx');
  XLSX.writeFile(wb, xlsxFileName);
};

export const downloadTextFile = (fileName, content) => {
  const blob = new Blob([content], { type: 'text/plain;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.setAttribute('download', fileName);
  link.setAttribute('href', url);
  link.click();
  URL.revokeObjectURL(url);
};

export const generateFileName = ({ type, to, businessHours = false }) => {
  let name = `${type}-report-${format(fromUnixTime(to), 'dd-MM-yyyy')}`;
  if (businessHours) {
    name = `${name}-business-hours`;
  }
  return `${name}.csv`;
};
