import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

// Helper class for Firestore pagination
class FirestorePaginator {
  final int loadItemCount;
  DocumentSnapshot? lastDocument;
  final Query query;
  final StreamController<QuerySnapshot> controller;
  bool hasMore = true;

  FirestorePaginator(
      this.query, {
        this.loadItemCount = 10,
      }) : controller = StreamController<QuerySnapshot>.broadcast();

  Stream<QuerySnapshot> get stream => controller.stream;

  void dispose() {
    controller.close();
  }

  Future<void> loadNextItems() async {
    if (!hasMore) return;

    Query paginatedQuery = query.limit(loadItemCount);
    if (lastDocument != null) {
      paginatedQuery = paginatedQuery.startAfterDocument(lastDocument!);
    }

    try {
      QuerySnapshot snapshot = await paginatedQuery.get();
      if (snapshot.docs.isEmpty) {
        hasMore = false;
      } else {
        lastDocument = snapshot.docs.last;
        controller.add(snapshot);
      }
    } catch (error) {
      controller.addError(error);
    }
  }
}



// Custom StreamBuilder class
class PaginatedStreamBuilder<T> extends StatelessWidget {
  final Stream<T> stream;
  final AsyncWidgetBuilder<T> builder;
  final FirestorePaginator paginator;

  PaginatedStreamBuilder({
    required this.stream,
    required this.builder,
    required this.paginator,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T>(
      stream: stream,
      builder: (BuildContext context, AsyncSnapshot<T> snapshot) {
        return builder(context, snapshot);
      },
    );
  }
}

// Custom ListView.builder class
class PaginatedListViewBuilder<T> extends StatelessWidget {
  final FirestorePaginator paginator;
  final IndexedWidgetBuilder itemBuilder;

  PaginatedListViewBuilder({
    required this.paginator,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
          paginator.loadNextItems();
        }
        return false;
      },
      child: StreamBuilder<T>(
        stream: paginator.stream as Stream<T>,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Something went wrong'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || (snapshot.data as dynamic).isEmpty) {
            return Center(
              child: Text('No data available'),
            );
          }

          List<DocumentSnapshot> items = snapshot.data as List<DocumentSnapshot>;
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) => itemBuilder(context, index),
          );
        },
      ),
    );
  }
}

