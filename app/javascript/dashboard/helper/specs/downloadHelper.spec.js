import * as XLSX from 'xlsx';
import { generateFileName, downloadXlsFile } from '../downloadHelper';

describe('#generateFileName', () => {
  it('should generate the correct file name', () => {
    expect(generateFileName({ type: 'csat', to: 1652812199 })).toEqual(
      'csat-report-17-05-2022.csv'
    );

    expect(
      generateFileName({ type: 'csat', to: 1652812199, businessHours: true })
    ).toEqual('csat-report-17-05-2022-business-hours.csv');
  });
});

describe('#downloadXlsFile', () => {
  beforeEach(() => {
    vi.spyOn(XLSX, 'writeFile').mockImplementation(() => {});
  });

  it('keeps date-like CSV cells as plain text instead of corrupting them into Excel serial numbers', () => {
    const csv = 'Date,Name,Count\n2026-06-08,Joao,1\n2026-06-09,Joao,42\n';

    downloadXlsFile('report.csv', csv);

    const wb = XLSX.writeFile.mock.calls[0][0];
    const sheet = wb.Sheets[wb.SheetNames[0]];

    expect(sheet.A2).toMatchObject({ t: 's', v: '2026-06-08' });
    expect(sheet.A3).toMatchObject({ t: 's', v: '2026-06-09' });
    expect(sheet.C2).toMatchObject({ t: 'n', v: 1 });
    expect(sheet.C3).toMatchObject({ t: 'n', v: 42 });
  });

  it('replaces the .csv extension with .xlsx', () => {
    downloadXlsFile('report.csv', 'A,B\n1,2\n');

    expect(XLSX.writeFile.mock.calls[0][1]).toEqual('report.xlsx');
  });
});
