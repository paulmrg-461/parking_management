from lpr_edge.tracker import Box, Tracker, TrackerConfig


def test_one_read_per_interval():
    tracker = Tracker(TrackerConfig(read_interval_ms=400))
    (track,) = tracker.update([Box(0, 0, 10, 10)], frame=1)
    assert tracker.should_read(track, now_ms=0) is True
    tracker.mark_read(track, now_ms=0)
    assert tracker.should_read(track, now_ms=399) is False
    assert tracker.should_read(track, now_ms=400) is True


def test_max_reads_per_track():
    tracker = Tracker(TrackerConfig(max_reads_per_track=2, read_interval_ms=0))
    (track,) = tracker.update([Box(0, 0, 10, 10)], frame=1)
    tracker.mark_read(track, now_ms=0)
    tracker.mark_read(track, now_ms=1)
    assert tracker.should_read(track, now_ms=2) is False


def test_best_crop_selected():
    tracker = Tracker()
    (track,) = tracker.update([Box(0, 0, 10, 10)], frame=1)
    assert tracker.offer_snapshot(track, b"first", score=0.5) is True
    assert tracker.offer_snapshot(track, b"worse", score=0.4) is False
    assert track.snapshot == b"first"
    assert tracker.offer_snapshot(track, b"best", score=0.9) is True
    assert track.snapshot == b"best"


def test_track_expires_after_max_age():
    tracker = Tracker(TrackerConfig(max_age_frames=2, iou_threshold=0.3))
    (first,) = tracker.update([Box(0, 0, 10, 10)], frame=1)
    assert first.id == "t-1"
    tracker.update([], frame=3)
    assert len(tracker.tracks) == 1
    tracker.update([], frame=4)
    assert tracker.tracks == []


def test_moves_keep_the_same_track():
    tracker = Tracker()
    (first,) = tracker.update([Box(0, 0, 10, 10)], frame=1)
    (second,) = tracker.update([Box(1, 1, 11, 11)], frame=2)
    assert second.id == first.id
    (new,) = tracker.update([Box(100, 100, 110, 110)], frame=3)
    assert new.id != first.id
