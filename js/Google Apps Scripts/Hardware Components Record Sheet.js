function onEdit(e) {
  // 
  applyBorders(e);
}


function applyBorders(e) {
  //
  const sheet = e.source.getActiveSheet(); // Gets the currently active sheet

  const maxRows = sheet.getLastRow();
  const maxColumns = sheet.getMaxColumns();

  const rangeForBorder = sheet.getRange(2, 5, maxRows - 1, 6); // (Row: 2 to Last, Column: E to J)
  rangeForBorder.setBorder(false, true, false, true, false, false, '#ccc', null) // Left and right border

}

// onEdit({
//   user: Session.getActiveUser().getEmail(),
//   source: SpreadsheetApp.getActiveSpreadsheet(),
//   range: SpreadsheetApp.getActiveSpreadsheet().getActiveCell(),
//   value: SpreadsheetApp.getActiveSpreadsheet().getActiveCell().getValue(),
//   authMode: 'LIMITED',
// });
