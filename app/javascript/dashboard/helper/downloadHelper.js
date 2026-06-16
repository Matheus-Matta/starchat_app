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

export const downloadXlsFile = (fileName, csvContent) => {
  const wb = XLSX.read(csvContent, { type: 'string' });
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
