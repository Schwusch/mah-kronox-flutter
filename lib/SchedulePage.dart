import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'Drawer.dart';
import 'FullScreenBooking.dart';

import 'utils/fetchBookings.dart';
import 'utils/Booking.dart';
import 'utils/Week.dart';
import 'utils/Day.dart';
import 'utils/ScheduleMeta.dart';

import 'redux/store.dart';
import 'redux/actions.dart';

class SchedulePage extends StatefulWidget {
  final String title;
  static final String path = "/";

  SchedulePage({Key k, this.title}) : super(key: k);

  @override
  _SchedulePageState createState() => new _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      new GlobalKey<RefreshIndicatorState>();
  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();
  var _subscribtion;
  List<Booking> bookings = [];
  DateFormat timeFormatter = new DateFormat("HH:mm", "sv_SE");

  _SchedulePageState() {
    if (scheduleStore.state.schedules.isNotEmpty) {
      fetchAndSetBookings();
    }
  }

  Future<Null> fetchAndSetBookings() {
    final Completer<Null> completer = new Completer<Null>();
    if (scheduleStore.state.currentSchedule != null) {
      fetchAllSchedules(scheduleStore.state.schedules).then((weeks) {
        completer.complete(null);
        scheduleStore
            .dispatch(new SetWeeksForCurrentScheduleAction(weeks: weeks));
      });
    } else {
      completer.complete(null);
    }

    return completer.future.then((_) {
      _scaffoldKey.currentState?.showSnackBar(new SnackBar(
          content: const Text("Scheman uppdaterade"),
          action: new SnackBarAction(
              label: 'IGEN',
              onPressed: () {
                _refreshIndicatorKey.currentState.show();
              })));
    });
  }

  @override
  void initState() {
    super.initState();
    _subscribtion = scheduleStore.onChange.listen((_) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    super.dispose();
    _subscribtion.cancel();
  }

  Widget _createScheduleItem(Booking booking) {
    String teachers = "";
    Map signaturemap = scheduleStore.state.signatureMap;

    for (String teacher in booking.signatures) {
      teachers += (signaturemap[teacher] ?? teacher) + ", ";
    }

    Iterable<Widget> locations =
        booking.location.split(" ").map((loc) => new Text(
              loc,
              style:
                  new TextStyle(color: themeStore.state.accentColor.shade700),
            ));

    List<Widget> leftColumnChildren = [
      new Text(timeFormatter.format(booking.start),
          style: new TextStyle(
              fontSize: 24.0,
              color: themeStore.state.primaryColor.shade200,
              fontWeight: FontWeight.bold)),
      new Text(timeFormatter.format(booking.end),
          style: new TextStyle(
              fontSize: 24.0,
              color: themeStore.state.theme.textTheme.caption.color,
              fontWeight: FontWeight.bold)),
    ];

    leftColumnChildren.addAll(locations);

    return new Card(
        elevation: 3.0,
        child: new InkWell(
          onLongPress: () {
            Navigator.push(
                context,
                new MaterialPageRoute(
                  builder: (BuildContext context) =>
                      new FullScreenBooking(booking: booking),
                  fullscreenDialog: true,
                ));
          },
          child: new Row(
            children: <Widget>[
              new Container(
                child: new Column(
                  children: leftColumnChildren,
                ),
                padding: new EdgeInsets.all(5.0),
                width: 110.0,
              ),
              new Flexible(
                  child: new Container(
                child: new Column(
                  children: <Widget>[
                    new Text(booking.course),
                    new Text(teachers,
                        style: new TextStyle(
                            color:
                                themeStore.state.theme.textTheme.caption.color,
                            fontWeight: FontWeight.bold)),
                    new Text(booking.moment)
                  ],
                  crossAxisAlignment: CrossAxisAlignment.start,
                ),
                padding: new EdgeInsets.all(5.0),
              ))
            ],
          ),
        ));
  }

  Widget _createDayCard(Day day) {
    return new Column(
      children: <Widget>[
        new Row(
          children: <Widget>[
            new Padding(
                padding:
                    new EdgeInsets.symmetric(vertical: 2.0, horizontal: 10.0),
                child: new Text(
                  day.date,
                  textAlign: TextAlign.center,
                  style: new TextStyle(fontWeight: FontWeight.w500),
                )),
          ],
        ),
        new Padding(
            padding: new EdgeInsets.all(5.0),
            child: new Column(
                children: day.bookings
                    .map((booking) => _createScheduleItem(booking))
                    .toList(growable: false)))
      ],
    );
  }

  Widget buildTabbedBody() {
    ScheduleMeta currentSchedule = scheduleStore.state.currentSchedule;
    List<Week> weeksToDisplay =
        scheduleStore.state.weeksMap[currentSchedule.name];

    return new DefaultTabController(
      length: weeksToDisplay.length,
      initialIndex: 0,
      child: new Scaffold(
        drawer: new ScheduleDrawer(),
        key: _scaffoldKey,
        body: new NestedScrollView(
            headerSliverBuilder:
                (BuildContext context, bool innerBoxIsScrolled) {
              return <Widget>[
                new SliverAppBar(
                    title: new Text(currentSchedule?.givenName ?? widget.title),
                    pinned: true,
                    forceElevated: innerBoxIsScrolled,
                    bottom: new TabBar(
                      tabs: weeksToDisplay
                          ?.map(
                              (Week week) => new Tab(text: "v. ${week.number}"))
                          ?.toList(),
                      isScrollable: true,
                    ),
                    actions: <Widget>[
                      new IconButton(
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Refresh',
                          onPressed: () {
                            _refreshIndicatorKey.currentState?.show();
                          }),
                      new IconButton(
                          icon: const Icon(Icons.info),
                          tooltip: 'Information',
                          onPressed: () {
                            showDialog(
                                context: context,
                                child: new SimpleDialog(
                                  title: new Text(currentSchedule?.givenName),
                                  children: <Widget>[
                                    new ListTile(
                                      title: new Text(currentSchedule.name),
                                      subtitle:
                                          new Text(currentSchedule.description),
                                    ),
                                    new ButtonTheme.bar(
                                      child: new ButtonBar(
                                        children: <Widget>[
                                          new FlatButton(
                                              child: const Text('OK'),
                                              onPressed: () =>
                                                  Navigator.of(context).pop())
                                        ],
                                      ),
                                    ),
                                  ],
                                ));
                          })
                    ]),
              ];
            },
            body: new RefreshIndicator(
                onRefresh: fetchAndSetBookings,
                key: _refreshIndicatorKey,
                child: new TabBarView(
                    children: weeksToDisplay.map((Week week) {
                  return new ListView(
                      children:
                          week.days.map((day) => _createDayCard(day)).toList());
                })?.toList()))),
      ),
    );
  }

  Widget buildEmptyBody(String message) {
    return new Scaffold(
      drawer: new ScheduleDrawer(),
      body: new Center(child: new Text(message)),
      appBar: new AppBar(
        title: new Text(scheduleStore.state.currentSchedule?.givenName ??
            "Inget schema valt"),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ScheduleMeta currentSchedule = scheduleStore.state.currentSchedule;
    List<Week> weeksToDisplay =
        scheduleStore.state.weeksMap[currentSchedule?.name];

    if (currentSchedule == null) {
      return buildEmptyBody("Inget schema valt");
    } else if (weeksToDisplay == null || weeksToDisplay.isEmpty) {
      return buildEmptyBody(
          "Det finns inga lektioner för ${currentSchedule.givenName}");
    } else {
      return buildTabbedBody();
    }
  }
}
