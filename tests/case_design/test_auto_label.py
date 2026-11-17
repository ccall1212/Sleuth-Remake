from case_design.auto_label import auto_label, label_spot, wall_of


def room(obstacles, kinds):
    return {"walk_regions": [[24, 150, 432, 172]], "obstacles": obstacles, "obstacle_kinds": kinds, "guest_spots": []}


def test_wall_detection():
    r = room([], [])
    assert wall_of([84, 148, 192, 24], r) == "north"       # long shelf on the north wall
    assert wall_of([428, 196, 28, 124], r) == "east"
    assert wall_of([24, 292, 124, 28], r) == "south"
    assert wall_of([24, 200, 16, 40], r) == "west"
    assert wall_of([200, 220, 60, 40], r) is None            # free-standing


def test_bookshelf_on_each_wall_is_browsed_from_the_open_side():
    cases = {
        "north": ([100, 150, 120, 24], [150, 190]),
        "south": ([100, 298, 120, 24], [150, 280]),
        "east": ([432, 180, 24, 100], [410, 230]),
        "west": ([24, 180, 24, 100], [64, 230]),
    }
    for wall, (rect, spot) in cases.items():
        r = room([rect], ["bookshelf"])
        assert label_spot(r, spot) == ("browse", wall), wall


def test_a_stool_on_the_east_wall_is_sat_on_facing_west():
    r = room([[432, 220, 24, 24]], ["stool"])
    assert label_spot(r, [430, 232]) == ("seat", "west")   # on the stool, just outside its rectangle
    r = room([[100, 298, 24, 24]], ["stool"])
    assert label_spot(r, [112, 294]) == ("seat", "north")  # south-wall stool: faces into the room


def test_a_free_standing_chair_faces_the_nearest_table_else_any():
    r = room([[200, 220, 24, 24], [260, 220, 60, 30]], ["armchair", "coffee_table"])
    assert label_spot(r, [212, 216]) == ("seat", "east")
    r = room([[200, 220, 24, 24]], ["armchair"])
    assert label_spot(r, [212, 216]) == ("seat", "any")


def test_plain_standing_spots_are_any_and_far_spots_do_not_use_furniture():
    r = room([[100, 150, 120, 24]], ["bookshelf"])
    assert label_spot(r, [300, 260]) == ("stand", "any")


def test_auto_label_rewrites_lists_and_keeps_positions():
    r = room([[100, 150, 120, 24]], ["bookshelf"])
    r["guest_spots"] = [[150, 190], [300, 260]]
    layout = {"screens": [r]}
    out = auto_label(layout)["screens"][0]
    assert out["guest_spots"] == [[150, 190], [300, 260]]
    assert out["guest_spot_kinds"] == ["browse", "stand"]
    assert out["guest_spot_facing"] == ["north", "any"]


def test_a_sofa_faces_across_its_length_toward_the_table_wherever_you_sit_on_it():
    r = room([[192, 252, 96, 16], [232, 220, 16, 12]], ["sofa", "coffee_table"])
    for x in (200, 240, 280):
        assert label_spot(r, [x, 248]) == ("seat", "north"), x


def test_standing_at_a_long_table_faces_it_across_the_short_side():
    r = room([[84, 200, 192, 24]], ["table"])          # free-standing long table
    assert label_spot(r, [124, 236]) == ("table", "north")
    assert label_spot(r, [124, 190]) == ("table", "south")
    assert label_spot(r, [60, 212]) == ("table", "east")
