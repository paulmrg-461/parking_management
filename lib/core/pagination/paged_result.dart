import 'package:equatable/equatable.dart';

/// One page of a list endpoint. [total] comes from `X-Total-Count`; when the
/// server does not send it (older backend) [hasMoreAfter] is always `false`,
/// so clients never request pages the server cannot slice.
class PagedResult<T> extends Equatable {
  const PagedResult(this.items, {this.total});

  final List<T> items;
  final int? total;

  bool hasMoreAfter(int loaded) {
    final known = total;
    return known != null && known > loaded;
  }

  @override
  List<Object?> get props => [items, total];
}

/// Default page size for paginated lists.
const defaultPageSize = 50;
