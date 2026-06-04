import math
from urllib.parse import unquote

import plotly.graph_objects as go
import plotly.io as pio
import psycopg2
from fastapi import FastAPI, Response

pio.templates.default = go.layout.Template(
    layout=dict(
        width=550,
        height=500,
    )
)

app = FastAPI()

TRANSPARENT_LAYOUT = dict(
    paper_bgcolor="rgba(0,0,0,0)",
    plot_bgcolor="rgba(0,0,0,0)",
)


@app.get("/treemap/{election_type}/{election_year}/{office}/{territory_key}")
def treemap_req(
    election_type: str,
    election_year: int,
    office: str,
    territory_key: int,
):
    conn = get_conn()
    cursor = conn.cursor()

    try:
        cursor.execute(
            """
            SELECT sigla, votes, color
            FROM wh.results_for_territory_parties(
                %s::text,
                %s::integer,
                %s::text,
                %s::bigint
            )
            WHERE COALESCE(votes, 0) > 0
            ORDER BY
                wh.political_entity_order(sigla) ASC,
                votes DESC,
                sigla ASC;
            """,
            (
                election_type,
                election_year,
                office,
                territory_key,
            ),
        )

        rows = cursor.fetchall()

    finally:
        cursor.close()
        conn.close()

    if not rows:
        return Response(
            content="",
            media_type="image/svg+xml",
        )

    labels = [str(r[0]) for r in rows]
    values = [int(r[1] or 0) for r in rows]
    colors = [normalize_color(str(r[2] or "#B3C6BC")) for r in rows]

    election_type = election_type.upper()

    svg = treemap_svg(
        labels,
        values,
        colors,
        title="How did each party stack up against each other?",
    )

    return Response(content=svg, media_type="image/svg+xml")


def treemap_svg(
    labels: list[str], values: list[int], colors: list[str], title: str
) -> str:
    fig = go.Figure(
        go.Treemap(
            labels=labels,
            parents=[""] * len(labels),
            values=values,
            marker=dict(colors=colors, line=dict(color="#162620", width=1)),
        )
    )

    fig.update_layout(
        title={
            "text": title,
            "x": 0.5,
            "xanchor": "center",
            "font": {"color": "#ECF5F0"},
        },
        margin=dict(l=0, r=0, t=50, b=0),
        paper_bgcolor=TRANSPARENT_LAYOUT["paper_bgcolor"],
        plot_bgcolor=TRANSPARENT_LAYOUT["plot_bgcolor"],
    )

    return fig.to_image(format="svg").decode("utf-8")


@app.get("/riseandfall/{election_type}/{office}/{territory_key}/{metric}/{direction}")
def riseandfall_req(
    election_type: str,
    office: str,
    territory_key: int,
    metric: str,
    direction: str,
):
    election_type = unquote(election_type).upper()
    office = unquote(office)
    metric = unquote(metric)
    direction = unquote(direction)

    conn = get_conn()
    cursor = conn.cursor()

    try:
        cursor.execute(
            """
            SELECT
                election_year,
                sigla,
                name,
                color,
                value,
                votes,
                seats,
                variation_value,
                variation_direction
            FROM wh.rise_and_fall(
                %s::text,
                %s::text,
                %s::bigint,
                %s::text,
                %s::text
            );
            """,
            (
                election_type,
                office,
                territory_key,
                metric,
                direction,
            ),
        )

        rows = cursor.fetchall()

    finally:
        cursor.close()
        conn.close()

    if not rows:
        return Response(
            content="",
            media_type="image/svg+xml",
        )

    rows = sorted(
        rows,
        key=lambda row: float(row[4] or 0),
        reverse=True,
    )[:20]

    years = sorted({str(row[0]) for row in rows})

    parties: list[str] = []
    for row in rows:
        party = str(row[1])
        if party not in parties:
            parties.append(party)

    fig = go.Figure()

    for party in parties:
        party_rows = [row for row in rows if str(row[1]) == party]

        values_by_year = {str(row[0]): float(row[4] or 0) for row in party_rows}
        values = [values_by_year.get(year, 0) for year in years]

        labels = [
            str(int(value)) if value == int(value) else str(round(value, 2))
            for value in values
        ]

        color = normalize_color(str(party_rows[0][3] or "#B3C6BC"))

        fig.add_trace(
            go.Bar(
                x=years,
                y=values,
                name=party,
                text=labels,
                marker_color=color,
                marker_line_color="#162620",
                marker_line_width=1,
            )
        )

    fig.update_traces(
        texttemplate="%{text}",
        textposition="outside",
        hoverinfo="skip",
        hovertemplate=None,
        textfont=dict(color="#B3C6BC"),
    )

    direction_label = "rising" if direction == "rise" else "falling"
    metric_label = "seats" if metric == "seats" else "votes"

    fig.update_layout(
        barmode="group",
        title={
            "text": f"Top {direction_label} parties by {metric_label}",
            "x": 0.5,
            "xanchor": "center",
            "font": {"color": "#ECF5F0"},
        },
        xaxis=dict(title="Election year", color="#B3C6BC", gridcolor="#162620"),
        yaxis=dict(
            title="Seats" if metric == "seats" else "Votes",
            color="#B3C6BC",
            gridcolor="#162620",
        ),
        legend=dict(font=dict(color="#B3C6BC")),
        showlegend=True,
        margin=dict(l=40, r=20, t=60, b=40),
        paper_bgcolor=TRANSPARENT_LAYOUT["paper_bgcolor"],
        plot_bgcolor=TRANSPARENT_LAYOUT["plot_bgcolor"],
    )

    svg = fig.to_image(format="svg").decode("utf-8")

    return Response(content=svg, media_type="image/svg+xml")


@app.get("/distribution/{election_type}/{election_year}/{office}/{territory_key}")
def distribution_req(
    election_type: str,
    election_year: int,
    office: str,
    territory_key: int,
):
    election_type = unquote(election_type)
    office = unquote(office)

    territory_info = fetch_territory_info(territory_key)

    if territory_info is None:
        return Response(
            content="",
            media_type="image/svg+xml",
        )

    territory_code = territory_info["territory_code"]
    territory_name = territory_info["territory_name"]
    territory_level = territory_info["territory_level"]

    election_name = f"{election_type.upper()} {election_year}"

    mode = distribution_mode(
        election_type=election_type,
        office=office,
        territory_code=territory_code,
        territory_level=territory_level,
    )

    if mode == "seat_distribution":
        rows = fetch_seat_distribution_rows(
            election_type=election_type,
            election_year=election_year,
            office=office,
            territory_key=territory_key,
        )

        if not rows:
            return Response(
                content="",
                media_type="image/svg+xml",
            )

        parties = [str(row[0]) for row in rows]
        seats = [int(row[1] or 0) for row in rows]
        colors = [normalize_color(str(row[2] or "#B3C6BC")) for row in rows]

        election_type = election_type.upper()

        svg = parliament_svg(
            parties=parties,
            seats=seats,
            colors=colors,
            title=f"Who did {territory_name} chose to represent their interests?",
        )

        return Response(content=svg, media_type="image/svg+xml")

    if mode == "elected_distribution":
        row = fetch_elected_row(
            election_type=election_type,
            election_year=election_year,
            office=office,
            territory_key=territory_key,
        )

        if not row:
            return Response(
                content="",
                media_type="image/svg+xml",
            )

        party = str(row[0])
        votes = int(row[1] or 0)
        color = normalize_color(str(row[2] or "#B3C6BC"))

        election_type = election_type.upper()

        svg = elected_svg(
            party=party,
            votes=votes,
            color=color,
            title=f"Elected party — {election_type} {election_year}",
        )

        return Response(content=svg, media_type="image/svg+xml")

    rows = fetch_seat_distribution_rows(
        election_type=election_type,
        election_year=election_year,
        office=office,
        territory_key=territory_key,
    )

    if not rows:
        return Response(
            content="",
            media_type="image/svg+xml",
        )

    parties = [str(row[0]) for row in rows]
    seats = [int(row[1] or 0) for row in rows]
    colors = [normalize_color(str(row[2] or "#B3C6BC")) for row in rows]

    election_type = election_type.upper()

    svg = square_bar_svg(
        parties=parties,
        values=seats,
        colors=colors,
        title=f"Who did {territory_name} chose to represent their interests?",
        y_title="Seats",
    )

    return Response(content=svg, media_type="image/svg+xml")


@app.get("/abstention/{election_type}/{election_year}/{office}/{territory_key}")
def abstention_req(
    election_type: str,
    election_year: int,
    office: str,
    territory_key: int,
):
    election_type = unquote(election_type)
    office = unquote(office)

    row = fetch_abstention_row(
        election_type=election_type,
        election_year=election_year,
        office=office,
        territory_key=territory_key,
    )

    if not row:
        return Response(
            content="",
            media_type="image/svg+xml",
        )

    territory_name = str(row[2])
    territory_level = str(row[3])

    registered_voters = int(row[5] or 0)
    voters = int(row[6] or 0)
    abstentions = int(row[7] or 0)

    turnout_rate = float(row[8] or 0)
    abstention_rate = float(row[9] or 0)

    blank_votes = int(row[10] or 0)
    null_votes = int(row[11] or 0)
    candidate_votes = int(row[12] or 0)

    svg = abstention_svg(
        election_type=election_type.upper(),
        election_year=election_year,
        office=office.upper(),
        territory_name=territory_name,
        territory_level=territory_level,
        registered_voters=registered_voters,
        voters=voters,
        abstentions=abstentions,
        turnout_rate=turnout_rate,
        abstention_rate=abstention_rate,
        blank_votes=blank_votes,
        null_votes=null_votes,
        candidate_votes=candidate_votes,
    )

    return Response(content=svg, media_type="image/svg+xml")


def distribution_mode(
    election_type: str,
    office: str,
    territory_code: str,
    territory_level: str,
) -> str:
    election_type = election_type.upper()
    office = office.upper()
    territory_code = territory_code.upper()
    territory_level = territory_level.lower()

    if election_type == "LEGISLATIVAS" and office == "AR":
        if territory_code == "PT" or territory_level == "country":
            return "seat_distribution"
        return "aggregate_distribution"

    if election_type == "AUTARQUICAS" and office == "AM":
        if territory_code == "PT" or territory_level == "country":
            return "aggregate_distribution"
        return "seat_distribution"

    if election_type == "AUTARQUICAS" and office == "AF":
        if territory_code == "PT" or territory_level == "country":
            return "aggregate_distribution"
        return "seat_distribution"

    if election_type == "AUTARQUICAS" and office == "CM":
        return "elected_distribution"

    return "aggregate_distribution"


def fetch_territory_info(territory_key: int) -> dict[str, str] | None:
    conn = get_conn()
    cursor = conn.cursor()

    try:
        cursor.execute(
            """
            SELECT
                territory_code,
                territory_name,
                territory_level
            FROM wh.dim_territory
            WHERE territory_key = %s::bigint
            LIMIT 1;
            """,
            (territory_key,),
        )

        row = cursor.fetchone()

        if not row:
            return None

        return {
            "territory_code": str(row[0]),
            "territory_name": str(row[1]),
            "territory_level": str(row[2]),
        }

    finally:
        cursor.close()
        conn.close()


def fetch_seat_distribution_rows(
    election_type: str,
    election_year: int,
    office: str,
    territory_key: int,
):
    conn = get_conn()
    cursor = conn.cursor()

    try:
        cursor.execute(
            """
            SELECT
                sigla,
                seats,
                color
            FROM wh.results_for_territory_parties(
                %s::text,
                %s::integer,
                %s::text,
                %s::bigint
            )
            WHERE COALESCE(seats, 0) > 0
            ORDER BY
                wh.political_entity_order(sigla) ASC,
                seats DESC,
                sigla ASC;
            """,
            (
                election_type,
                election_year,
                office,
                territory_key,
            ),
        )

        return cursor.fetchall()

    finally:
        cursor.close()
        conn.close()


def fetch_elected_row(
    election_type: str,
    election_year: int,
    office: str,
    territory_key: int,
):
    conn = get_conn()
    cursor = conn.cursor()

    try:
        cursor.execute(
            """
            SELECT
                sigla,
                votes,
                color
            FROM wh.results_for_territory_parties(
                %s::text,
                %s::integer,
                %s::text,
                %s::bigint
            )
            WHERE COALESCE(votes, 0) > 0
            ORDER BY
                votes DESC,
                wh.political_entity_order(sigla) ASC,
                sigla ASC
            LIMIT 1;
            """,
            (
                election_type,
                election_year,
                office,
                territory_key,
            ),
        )

        return cursor.fetchone()

    finally:
        cursor.close()
        conn.close()


def parliament_svg(
    parties: list[str],
    seats: list[int],
    colors: list[str],
    title: str,
) -> str:
    total_seats = sum(seats)

    if total_seats <= 0:
        return ""

    rows = max(3, min(10, int(math.sqrt(total_seats))))
    radii = [0.35 + (i / max(rows - 1, 1)) * 0.65 for i in range(rows)]

    weights = radii
    total_weight = sum(weights)

    points_per_row = [
        max(1, round(total_seats * weight / total_weight)) for weight in weights
    ]

    diff = total_seats - sum(points_per_row)
    points_per_row[-1] += diff

    seat_positions: list[tuple[float, float]] = []

    for radius, count in zip(radii, points_per_row):
        if count <= 1:
            angles = [90]
        else:
            angles = [180 - (180 * i / (count - 1)) for i in range(count)]

        for angle in angles:
            seat_positions.append((radius, angle))

    seat_positions = sorted(
        seat_positions,
        key=lambda item: (-item[1], item[0]),
    )

    fig = go.Figure()

    index = 0

    for party, party_seats, color in zip(parties, seats, colors):
        party_positions = seat_positions[index : index + party_seats]
        index += party_seats

        r_values = [pos[0] for pos in party_positions]
        theta_values = [pos[1] for pos in party_positions]

        fig.add_trace(
            go.Scatterpolar(
                r=r_values,
                theta=theta_values,
                mode="markers",
                name=f"{party} ({party_seats})",
                marker=dict(
                    size=12,
                    color=color,
                    line=dict(width=1, color="#162620"),
                ),
                hoverinfo="skip",
            )
        )

    fig.update_layout(
        title={
            "text": title,
            "x": 0.5,
            "xanchor": "center",
            "font": {"color": "#ECF5F0"},
        },
        legend=dict(
            font=dict(color="#B3C6BC"),
            orientation="h",
            x=0.5,
            xanchor="center",
            y=0.18,
            yanchor="top",
        ),
        showlegend=True,
        polar=dict(
            bgcolor="rgba(0,0,0,0)",
            domain=dict(x=[0, 1], y=[0.15, 1.0]),  # push polar up, free space below
            radialaxis=dict(visible=False),
            angularaxis=dict(visible=False),
            sector=[0, 180],  # explicitly clip to top semicircle only
        ),
        margin=dict(l=20, r=20, t=50, b=20),
        paper_bgcolor=TRANSPARENT_LAYOUT["paper_bgcolor"],
        plot_bgcolor=TRANSPARENT_LAYOUT["plot_bgcolor"],
    )

    return fig.to_image(format="svg").decode("utf-8")


def square_bar_svg(
    parties: list[str],
    values: list[int],
    colors: list[str],
    title: str,
    y_title: str,
) -> str:
    # Keep SQL order. Do not sort by value here.
    items = list(zip(parties, values, colors))[:20]

    parties = [item[0] for item in items]
    values = [item[1] for item in items]
    colors = [item[2] for item in items]

    fig = go.Figure()

    for party, value, color in zip(parties, values, colors):
        fig.add_trace(
            go.Bar(
                x=[party],
                y=[value],
                name=party,
                text=[value],
                marker_color=color,
                marker_line_width=1,
                marker_line_color="#162620",
            )
        )

    fig.update_traces(
        texttemplate="%{text}",
        textposition="outside",
        hoverinfo="skip",
        hovertemplate=None,
        width=0.65,
        textfont=dict(color="#B3C6BC"),
    )

    fig.update_layout(
        title={
            "text": title,
            "x": 0.5,
            "xanchor": "center",
            "font": {"color": "#ECF5F0"},
        },
        xaxis=dict(title="Party", color="#B3C6BC", gridcolor="#162620"),
        yaxis=dict(title=y_title, color="#B3C6BC", gridcolor="#162620"),
        showlegend=False,
        margin=dict(l=40, r=20, t=70, b=80),
        paper_bgcolor=TRANSPARENT_LAYOUT["paper_bgcolor"],
        plot_bgcolor=TRANSPARENT_LAYOUT["plot_bgcolor"],
    )

    return fig.to_image(format="svg").decode("utf-8")


def elected_svg(
    party: str,
    votes: int,
    color: str,
    title: str,
) -> str:
    fig = go.Figure()

    fig.add_trace(
        go.Scatter(
            x=[0],
            y=[0],
            mode="markers+text",
            marker=dict(
                size=90,
                color=color,
                line=dict(width=3, color="#162620"),
            ),
            text=[party],
            textposition="middle center",
            textfont=dict(
                size=22,
                color="#ECF5F0",
            ),
            hoverinfo="skip",
        )
    )

    fig.add_annotation(
        x=0,
        y=-0.45,
        text=f"{votes} votes",
        showarrow=False,
        font=dict(
            size=18,
            color="#B3C6BC",
        ),
    )

    fig.update_layout(
        title={
            "text": title,
            "x": 0.5,
            "xanchor": "center",
            "font": {"color": "#ECF5F0"},
        },
        xaxis=dict(
            visible=False,
            range=[-1, 1],
        ),
        yaxis=dict(
            visible=False,
            range=[-1, 1],
        ),
        plot_bgcolor="rgba(0,0,0,0)",
        paper_bgcolor="rgba(0,0,0,0)",
        showlegend=False,
        margin=dict(l=20, r=20, t=70, b=20),
    )

    return fig.to_image(format="svg").decode("utf-8")


def get_conn():
    conn = psycopg2.connect(database="elections", port="5432")
    conn.autocommit = True
    return conn


def normalize_color(color: str) -> str:
    color = color.strip()

    if len(color) == 7 and color.startswith("#"):
        return color

    if len(color) == 9 and color.startswith("#"):
        r = int(color[1:3], 16)
        g = int(color[3:5], 16)
        b = int(color[5:7], 16)
        a = int(color[7:9], 16) / 255
        return f"rgba({r},{g},{b},{a})"

    return "#B3C6BC"


def fetch_abstention_row(
    election_type: str,
    election_year: int,
    office: str,
    territory_key: int,
):
    conn = get_conn()
    cursor = conn.cursor()

    try:
        cursor.execute(
            """
            SELECT
                territory_key,
                territory_code,
                territory_name,
                territory_level,
                election_year,
                registered_voters,
                voters,
                abstentions,
                turnout_rate,
                abstention_rate,
                blank_votes,
                null_votes,
                candidate_votes
            FROM wh.abstention_for_territory(
                %s::text,
                %s::integer,
                %s::text,
                %s::bigint
            );
            """,
            (
                election_type,
                election_year,
                office,
                territory_key,
            ),
        )

        return cursor.fetchone()

    finally:
        cursor.close()
        conn.close()


def abstention_svg(
    election_type: str,
    election_year: int,
    office: str,
    territory_name: str,
    territory_level: str,
    registered_voters: int,
    voters: int,
    abstentions: int,
    turnout_rate: float,
    abstention_rate: float,
    blank_votes: int,
    null_votes: int,
    candidate_votes: int,
) -> str:
    abstention_pct = round(abstention_rate * 100, 2)
    turnout_pct = round(turnout_rate * 100, 2)

    fig = go.Figure()

    fig.add_trace(
        go.Pie(
            labels=["Abstained", "Voted"],
            values=[abstentions, voters],
            hole=0.72,
            sort=False,
            direction="clockwise",
            marker=dict(
                colors=["#F0F4F4", "#B0C4C6"],
                line=dict(color="#162620", width=2),
            ),
            textinfo="none",
            hoverinfo="skip",
            showlegend=False,
            domain=dict(x=[0.08, 0.92], y=[0.12, 0.88]),
        )
    )

    fig.add_annotation(
        x=0.5,
        y=0.53,
        xref="paper",
        yref="paper",
        text=f"<b>{abstention_pct:.1f}%</b>",
        showarrow=False,
        font=dict(size=42, color="#ECF5F0"),
    )

    fig.add_annotation(
        x=0.5,
        y=0.42,
        xref="paper",
        yref="paper",
        text="abstention",
        showarrow=False,
        font=dict(size=15, color="#B3C6BC"),
    )

    fig.add_annotation(
        x=0.5,
        y=0.97,
        xref="paper",
        yref="paper",
        text="",
        showarrow=False,
        font=dict(size=18, color="#ECF5F0"),
    )

    fig.add_annotation(
        x=0.5,
        y=0.04,
        xref="paper",
        yref="paper",
        text=(
            f"Adoption {turnout_pct:.1f}% · Voted {voters:,} · Abstained {abstentions:,}"
        ),
        showarrow=False,
        font=dict(size=12, color="#B3C6BC"),
    )

    fig.update_layout(
        width=700,
        height=420,
        margin=dict(l=10, r=10, t=20, b=20),
        paper_bgcolor=TRANSPARENT_LAYOUT["paper_bgcolor"],
        plot_bgcolor=TRANSPARENT_LAYOUT["plot_bgcolor"],
    )

    return fig.to_image(format="svg").decode("utf-8")


@app.get("/swingmap/{election_type}/{office}/{territory_key}")
def swingmap_req(
    election_type: str,
    office: str,
    territory_key: int,
):
    election_type = unquote(election_type).upper()
    office = unquote(office)

    parent_info = fetch_territory_info(territory_key)
    if parent_info is None:
        return Response(content="", media_type="image/svg+xml")

    child_level = child_territory_level(parent_info["territory_level"])
    if child_level is None:
        return Response(content="", media_type="image/svg+xml")

    year_range = fetch_election_year_range(election_type, office)
    if year_range is None:
        return Response(content="", media_type="image/svg+xml")

    from_year, to_year = year_range

    children = fetch_child_territories_with_geom(territory_key, child_level)
    if not children:
        return Response(content="", media_type="image/svg+xml")

    swing_rows = fetch_swing_for_children(
        election_type=election_type,
        office=office,
        from_year=from_year,
        to_year=to_year,
        child_keys=[c["territory_key"] for c in children],
    )

    swing_by_key = {row["territory_key"]: row for row in swing_rows}
    for child in children:
        swing = swing_by_key.get(child["territory_key"])
        child["swing_value"] = swing["swing_value"] if swing else None
        child["swing_direction"] = swing["swing_direction"] if swing else "unknown"
        child["from_margin"] = swing["from_margin"] if swing else None
        child["to_margin"] = swing["to_margin"] if swing else None

    svg = swingmap_svg(
        children=children,
        from_year=from_year,
        to_year=to_year,
        parent_name=parent_info["territory_name"],
    )

    return Response(content=svg, media_type="image/svg+xml")


def fetch_election_year_range(
    election_type: str, office: str
) -> tuple[int, int] | None:
    conn = get_conn()
    cursor = conn.cursor()

    try:
        cursor.execute(
            """
            SELECT
                MIN(e.election_year),
                MAX(e.election_year)
            FROM wh.dim_election e
            JOIN wh.fact_vote_result f
              ON f.election_key = e.election_key
            JOIN wh.dim_office o
              ON o.office_key = f.office_key
            WHERE e.election_type = %s
              AND o.office_code = %s;
            """,
            (election_type, office),
        )

        row = cursor.fetchone()

        if not row or row[0] is None or row[1] is None:
            return None

        return int(row[0]), int(row[1])

    finally:
        cursor.close()
        conn.close()


def child_territory_level(parent_level: str) -> str | None:
    order = ["country", "district", "municipality", "parish"]
    parent_level = parent_level.lower()
    if parent_level not in order:
        return None
    idx = order.index(parent_level)
    if idx + 1 >= len(order):
        return None
    return order[idx + 1]


def fetch_child_territories_with_geom(
    parent_territory_key: int,
    child_level: str,
) -> list[dict]:
    conn = get_conn()
    cursor = conn.cursor()

    try:
        cursor.execute(
            """
            SELECT
                child.territory_key,
                child.territory_code,
                child.territory_name,
                child.territory_level,
                ST_X(ST_Centroid(child.geom)) AS centroid_x,
                ST_Y(ST_Centroid(child.geom)) AS centroid_y,
                ST_AsGeoJSON(ST_SimplifyPreserveTopology(child.geom, 0.0001)) AS geojson
            FROM wh.dim_territory child
            JOIN wh.dim_territory parent
              ON parent.territory_key = %s::bigint
             AND child.parent_code = parent.territory_code
            WHERE child.territory_level = %s
              AND child.geom IS NOT NULL
            ORDER BY child.territory_code;
            """,
            (parent_territory_key, child_level),
        )

        rows = cursor.fetchall()
        return [
            {
                "territory_key": int(row[0]),
                "territory_code": str(row[1]),
                "territory_name": str(row[2]),
                "territory_level": str(row[3]),
                "centroid_x": float(row[4]),
                "centroid_y": float(row[5]),
                "geojson": row[6],
            }
            for row in rows
        ]

    finally:
        cursor.close()
        conn.close()


def fetch_swing_for_children(
    election_type: str,
    office: str,
    from_year: int,
    to_year: int,
    child_keys: list[int],
) -> list[dict]:
    if not child_keys:
        return []

    conn = get_conn()
    cursor = conn.cursor()

    try:
        cursor.execute(
            """
            SELECT
                territory_key,
                swing_value,
                swing_direction,
                from_margin,
                to_margin
            FROM wh.vote_swing_by_territory(
                %s::text,
                %s::text,
                %s::integer,
                %s::integer
            )
            WHERE territory_key = ANY(%s::bigint[]);
            """,
            (
                election_type,
                office,
                from_year,
                to_year,
                child_keys,
            ),
        )

        rows = cursor.fetchall()
        return [
            {
                "territory_key": int(row[0]),
                "swing_value": float(row[1]) if row[1] is not None else None,
                "swing_direction": str(row[2]),
                "from_margin": float(row[3]) if row[3] is not None else None,
                "to_margin": float(row[4]) if row[4] is not None else None,
            }
            for row in rows
        ]

    finally:
        cursor.close()
        conn.close()


def swingmap_svg(
    children: list[dict],
    from_year: int,
    to_year: int,
    parent_name: str,
) -> str:
    import json

    LEFT_COLOUR = "#E63946"
    RIGHT_COLOUR = "#3A86FF"
    NEUTRAL_COLOUR = "#162327"

    swing_values = [c["swing_value"] for c in children if c["swing_value"] is not None]
    max_abs = max((abs(v) for v in swing_values), default=1.0) or 1.0

    feature_collection = {
        "type": "FeatureCollection",
        "features": [],
    }

    for child in children:
        if child["geojson"] is None:
            continue
        geom = json.loads(child["geojson"])
        feature_collection["features"].append(
            {
                "type": "Feature",
                "id": str(child["territory_key"]),
                "geometry": geom,
                "properties": {"name": child["territory_name"]},
            }
        )

    territory_keys = [str(c["territory_key"]) for c in children]

    swing_labels = [
        (
            f"{c['territory_name']}<br>"
            f"Swing: {round(c['swing_value'] * 100, 1):+.1f}pp ({c['swing_direction']})<br>"
            f"Margin {from_year}: {round(c['from_margin'] * 100, 1) if c['from_margin'] is not None else 'N/A':+}pp<br>"
            f"Margin {to_year}: {round(c['to_margin'] * 100, 1) if c['to_margin'] is not None else 'N/A':+}pp"
            if c["swing_value"] is not None
            else f"{c['territory_name']}<br>No data"
        )
        for c in children
    ]

    fig = go.Figure()

    fig.add_trace(
        go.Choropleth(
            geojson=feature_collection,
            locations=territory_keys,
            z=[
                c["swing_value"] * 100 if c["swing_value"] is not None else 0
                for c in children
            ],
            colorscale=[
                [0.0, LEFT_COLOUR],
                [0.5, NEUTRAL_COLOUR],
                [1.0, RIGHT_COLOUR],
            ],
            zmin=-max_abs * 100,
            zmax=max_abs * 100,
            marker_line_color="#050D0E",
            marker_line_width=0.8,
            showscale=True,
            colorbar=dict(
                title=dict(text="Swing (pp)", font=dict(color="#B3C6BC")),
                tickfont=dict(color="#B3C6BC"),
                bgcolor="rgba(0,0,0,0)",
                outlinecolor="rgba(0,0,0,0)",
                orientation="h",
                x=0.5,
                y=-0.1,
                xanchor="center",
                yanchor="top",
            ),
            customdata=swing_labels,
            hovertemplate="%{customdata}<extra></extra>",
        )
    )

    all_lons = [c["centroid_x"] for c in children]
    all_lats = [c["centroid_y"] for c in children]

    lon_center = (min(all_lons) + max(all_lons)) / 2
    lat_center = (min(all_lats) + max(all_lats)) / 2
    lon_range = max(all_lons) - min(all_lons)
    lat_range = max(all_lats) - min(all_lats)

    lon_pad = max(lon_range * 0.15, 0.05)
    lat_pad = max(lat_range * 0.15, 0.05)

    fig.update_geos(
        visible=False,
        lonaxis_range=[min(all_lons) - lon_pad, max(all_lons) + lon_pad],
        lataxis_range=[min(all_lats) - lat_pad, max(all_lats) + lat_pad],
        projection_type="mercator",
        bgcolor="rgba(0,0,0,0)",
        showland=False,
        showcoastlines=False,
        showframe=False,
    )

    fig.update_layout(
        width=600,
        height=520,
        title={
            "text": f"Vote swing {from_year} → {to_year}",
            "x": 0.5,
            "xanchor": "center",
            "font": {"color": "#ECF5F0"},
        },
        margin=dict(l=0, r=0, t=50, b=50),
        paper_bgcolor=TRANSPARENT_LAYOUT["paper_bgcolor"],
        plot_bgcolor=TRANSPARENT_LAYOUT["plot_bgcolor"],
        geo=dict(
            center=dict(lon=lon_center, lat=lat_center),
        ),
    )

    return fig.to_image(format="svg").decode("utf-8")
