const config = {
  summary: {
    sheet_name: 'Summary',
  },
  cash: {
    sheet_name: 'Cash',
    updated_date_column_index: 6, // column F
  },
  investments: {
    sheet_name: 'Investments',
    updated_date_column_index: 6, // column F
  },
  liabilities: {
    sheet_name: 'Liabilities',
    updated_date_column_index: 6, // column F
  },
  recurring_expenses: {
    sheet_name: 'Recurring Expenses',
    invoice_updated_date_column_index: 6, // column F
    checkbox_column_index: 7, // column G
    updated_date_column_index: 8, // column H
  },
  planned_expenses: {
    sheet_name: 'Planned Expenses',
    updated_date_column_index: 5, // column E
  },
  receivables: {
    sheet_name: 'Receivables',
    updated_date_column_index: 5, // column E
  },
};

function onEdit(e) {
  //
  if (e !== undefined) {
    // 
    const sheet = e.source.getActiveSheet();
    const sheetName = sheet.getName();
    const sheetConfig = config[sheetName.toLowerCase().replace(/ /g, '_')];

    const editedRowIndex = e.range.getRow();
    const editedColumnIndex = e.range.getColumn();

    if (e.value !== e.oldValue) {
      if (
        sheetConfig &&
        sheetConfig.updated_date_column_index &&
        editedRowIndex > 3 &&
        editedColumnIndex !== sheetConfig.updated_date_column_index
      ) {
        //
        const dateCell = sheet.getRange(editedRowIndex, sheetConfig.updated_date_column_index);

        dateCell.setValue(new Date());
      }

      if (sheetName !== config.summary.sheet_name) {
        //
        const summarySheet = e.source.getSheetByName(config.summary.sheet_name);

        // Date cell in summary sheet (row 10, column G)
        const dateCellInSummarySheet = summarySheet.getRange(10, 7);
        dateCellInSummarySheet.setValue(new Date());
      }
    }
  }
}

function onOpen(e) {
  //
  const sheetConfig = config.recurring_expenses;
  const sheet = e.source.getSheetByName(sheetConfig.sheet_name);

  const lastRowIndex = sheet.getLastRow();

  // console.log(lastRowIndex);

  for (let rowIndex = 1; rowIndex <= lastRowIndex; rowIndex++) {
    //
    const dateCell = sheet.getRange(rowIndex, sheetConfig.invoice_updated_date_column_index);
    const checkBoxCell = sheet.getRange(rowIndex, sheetConfig.checkbox_column_index);

    const dateCellValue = dateCell.getValue();
    const currentDate = new Date();

    if (
      dateCellValue instanceof Date &&
      (currentDate.getMonth() > dateCellValue.getMonth() || currentDate.getFullYear() > dateCellValue.getFullYear()) &&
      checkBoxCell.isChecked()
    ) {
      //
      const nextInvoiceDate = new Date(dateCellValue);
      nextInvoiceDate.setMonth(nextInvoiceDate.getMonth() + 1);
      dateCell.setValue(nextInvoiceDate);

      checkBoxCell.setValue(false);
    }
  }
}

// onOpen({
//   user: Session.getActiveUser().getEmail(),
//   source: SpreadsheetApp.getActiveSpreadsheet(),
//   range: SpreadsheetApp.getActiveSpreadsheet().getActiveCell(),
//   value: SpreadsheetApp.getActiveSpreadsheet().getActiveCell().getValue(),
//   authMode: 'LIMITED',
// });
