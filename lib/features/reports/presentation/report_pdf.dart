import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/l10n/l10n.dart';
import '../../../core/receipt/pdf_table.dart';
import '../../../core/utils/cop_formatter.dart';
import '../../../core/utils/formatters.dart';
import '../domain/entities/hourly_traffic.dart';
import '../domain/entities/revenue_report.dart';

/// Builds the shareable PDF for the revenue report (active lot, or every site
/// when [allLots] was requested). Pure: no I/O, so it can be unit-tested.
Future<Uint8List> buildRevenueReportPdf({
  required AppLocalizations l10n,
  required RevenueReport revenue,
  required String headline,
  String? lotName,
  int? previousTotal,
  int? deltaPercent,
  HourlyTraffic? hourly,
}) {
  final doc = pw.Document();
  final hourlyRows = hourly == null
      ? const <({String label, String value})>[]
      : reportHourlyRows(l10n: l10n, hourly: hourly);
  final builder = PdfDocumentBuilder(
    title: headline,
    subtitle: lotName == null
        ? '${Formatters.date(revenue.startDate)} — ${Formatters.date(revenue.endDate)}'
        : '$lotName · ${Formatters.date(revenue.startDate)} — '
              '${Formatters.date(revenue.endDate)}',
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          '${context.pageNumber} / ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 8),
        ),
      ),
      build: (context) => [
        builder.build([
          PdfDocumentBuilder.row(
            l10n.reportsTotalRevenue,
            CopFormatter.format(revenue.total),
            bold: true,
          ),
          for (final row in reportComparisonRows(
            l10n: l10n,
            previousTotal: previousTotal,
            deltaPercent: deltaPercent,
          ))
            PdfDocumentBuilder.row(row.label, row.value),
          if (revenue.totalDiscounts > 0)
            PdfDocumentBuilder.row(
              l10n.reportsTotalDiscounts,
              '-${CopFormatter.format(revenue.totalDiscounts)}',
            ),
          if (revenue.discountedSessions > 0)
            PdfDocumentBuilder.row(
              l10n.reportsDiscountLog,
              '${revenue.discountedSessions}',
            ),
          if (revenue.passRevenue > 0)
            PdfDocumentBuilder.row(
              l10n.reportsPassRevenue,
              CopFormatter.format(revenue.passRevenue),
            ),
          if (revenue.byLot.isNotEmpty)
            PdfDocumentBuilder.section(l10n.reportsByLot, [
              for (final lot in revenue.byLot)
                PdfDocumentBuilder.row(
                  lot.lotName,
                  CopFormatter.format(lot.amount),
                ),
            ]),
          PdfDocumentBuilder.section(l10n.reportsRevenueByDay, [
            if (revenue.byDay.isNotEmpty) ...[
              buildRevenueBarChart(revenue.byDay),
              pw.SizedBox(height: 6),
            ],
            for (final day in revenue.byDay)
              PdfDocumentBuilder.row(
                Formatters.date(day.date),
                CopFormatter.format(day.amount),
              ),
          ]),
          if (hourlyRows.isNotEmpty)
            PdfDocumentBuilder.section(l10n.reportsHourlyTitle, [
              if (hourly != null) ...[
                buildHourlyBarChart(hourly),
                pw.SizedBox(height: 6),
              ],
              for (final row in hourlyRows)
                PdfDocumentBuilder.row(row.label, row.value),
            ]),
          PdfDocumentBuilder.section(l10n.reportsRevenueByCategory, [
            for (final category in revenue.byCategory)
              PdfDocumentBuilder.row(
                category.categoryName,
                CopFormatter.format(category.amount),
              ),
          ]),
          if (revenue.byPayment.isNotEmpty)
            PdfDocumentBuilder.section(l10n.reportsRevenueByPayment, [
              for (final payment in revenue.byPayment)
                PdfDocumentBuilder.row(
                  payment.paymentMethod,
                  CopFormatter.format(payment.amount),
                ),
            ]),
          if (revenue.discountAudit.isNotEmpty)
            PdfDocumentBuilder.section(l10n.reportsDiscountLog, [
              for (final discount in revenue.discountAudit)
                PdfDocumentBuilder.row(
                  '${discount.plate} · ${Formatters.date(discount.discountAt)}',
                  '-${CopFormatter.format(discount.discountAmount)}',
                ),
            ]),
        ]),
      ],
    ),
  );
  return doc.save();
}

/// Bar heights for the revenue-by-day chart in the PDF: the best day fills
/// [height], quiet days stay at zero. Pure so it can be unit-tested.
List<double> revenueBarHeights(List<DailyRevenue> byDay, {double height = 68}) {
  final max = byDay.fold<int>(
    0,
    (peak, day) => day.amount > peak ? day.amount : peak,
  );
  if (max <= 0) {
    return List<double>.filled(byDay.length, 0);
  }
  return [for (final day in byDay) height * day.amount / max];
}

/// Compact daily-revenue bar chart for the exported PDF: no axes, just the
/// shape, with the first and last date underneath. The table below keeps the
/// exact numbers, so the chart never needs labels on every bar.
pw.Widget buildRevenueBarChart(List<DailyRevenue> byDay, {double height = 68}) {
  if (byDay.isEmpty) {
    return pw.SizedBox();
  }
  final heights = revenueBarHeights(byDay, height: height);
  final gap = byDay.length > 15 ? 1.0 : 3.0;
  final color = PdfColor.fromHex('#2A78D6');
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.SizedBox(
        height: height,
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            for (final bar in heights)
              pw.Expanded(
                child: pw.Padding(
                  padding: pw.EdgeInsets.symmetric(horizontal: gap / 2),
                  child: pw.Container(
                    height: bar,
                    decoration: pw.BoxDecoration(color: color),
                  ),
                ),
              ),
          ],
        ),
      ),
      pw.SizedBox(height: 2),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            Formatters.date(byDay.first.date),
            style: const pw.TextStyle(fontSize: 8),
          ),
          pw.Text(
            Formatters.date(byDay.last.date),
            style: const pw.TextStyle(fontSize: 8),
          ),
        ],
      ),
    ],
  );
}

/// Bar heights for the hourly traffic chart: the busiest entry hour fills
/// [height], quiet hours stay at zero.
List<double> hourlyBarHeights(
  List<HourlyTrafficPoint> hours, {
  double height = 68,
}) {
  final max = hours.fold<int>(
    0,
    (peak, hour) => hour.entries > peak ? hour.entries : peak,
  );
  if (max <= 0) {
    return List<double>.filled(hours.length, 0);
  }
  return [for (final hour in hours) height * hour.entries / max];
}

/// Compact 24-hour entry chart for the exported PDF. Exits stay in the table
/// below, so the chart answers "when does the gate get busy?" at a glance.
pw.Widget buildHourlyBarChart(HourlyTraffic hourly, {double height = 68}) {
  if (hourly.hours.isEmpty) {
    return pw.SizedBox();
  }
  final heights = hourlyBarHeights(hourly.hours, height: height);
  final color = PdfColor.fromHex('#1BAF7A');
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.SizedBox(
        height: height,
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            for (final bar in heights)
              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 1),
                  child: pw.Container(
                    height: bar,
                    decoration: pw.BoxDecoration(color: color),
                  ),
                ),
              ),
          ],
        ),
      ),
      pw.SizedBox(height: 2),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          for (final label in const [
            '00:00',
            '06:00',
            '12:00',
            '18:00',
            '23:00',
          ])
            pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
        ],
      ),
    ],
  );
}

/// The period-over-period lines of the PDF. Empty when the previous window is
/// unknown, so the report never invents a comparison.
List<({String label, String value})> reportComparisonRows({
  required AppLocalizations l10n,
  int? previousTotal,
  int? deltaPercent,
}) {
  final previous = previousTotal;
  final delta = deltaPercent;
  if (previous == null || delta == null) {
    return const [];
  }
  final sign = delta > 0 ? '+' : '';
  return [
    (label: l10n.reportsVariationLabel, value: '$sign$delta %'),
    (label: l10n.reportsPreviousLabel, value: CopFormatter.format(previous)),
  ];
}

/// The hourly table of the PDF: one row per hour with movement (quiet hours
/// add noise to a printed report). Empty when there was no traffic.
List<({String label, String value})> reportHourlyRows({
  required AppLocalizations l10n,
  required HourlyTraffic hourly,
}) => [
  for (final point in hourly.hours)
    if (point.total > 0)
      (
        label: point.timeLabel,
        value: l10n.reportsHourlyPair(point.entries, point.exits),
      ),
];
