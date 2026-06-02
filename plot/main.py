import math
from urllib.parse import unquote

import plotly.graph_objects as go
import psycopg2
from fastapi import FastAPI, Response

app = FastAPI()

TRANSPARENT_LAYOUT = dict(
    paper_bgcolor="rgba(0,0,0,0)",
    plot_bgcolor="rgba(0,0,0,0)",
)


@app.get(
    "/treemap/{election_type}/{election_year}/{office}/{territory_code}/{territory_level}"
)
def treemap_req(
    election_type: str,
    election_year: int,
    office: str,
    territory_code: str,
    territory_level: str,
):
    election_type = unquote(election_type)
    office = unquote(office)
    territory_code = unquote(territory_code)
    territory_level = unquote(territory_level)

    conn = get_conn()
    cursor = conn.cursor()

    try:
        cursor.execute(
            """
            SELECT sigla, votes
            FROM wh.results_for_territory_parties(
                %s, %s, %s, %s, %s
            );
            """,
            (
                election_type,
                election_year,
                office,
                territory_code,
                territory_level,
            ),
        )

        rows = cursor.fetchall()

    finally:
        cursor.close()
        conn.close()

    if not rows:
        return Response(
            content=svg_message("No data found"),
            media_type="image/svg+xml",
        )

    labels = [str(r[0]) for r in rows]
    values = [int(r[1] or 0) for r in rows]

    svg = treemap_svg(labels, values)

    return Response(content=svg, media_type="image/svg+xml")


def treemap_svg(labels: list[str], values: list[int]) -> str:
    fig = go.Figure(
        go.Treemap(
            labels=labels,
            parents=[""] * len(labels),
            values=values,
        )
    )

    fig.update_layout(
        margin=dict(l=0, r=0, t=0, b=0),
    )

    return fig.to_image(format="svg").decode("utf-8")


@app.get(
    "/riseandfall/{election_type}/{office}/{territory_code}/{territory_level}/{metric}/{direction}/"
)
def riseandfall_req(
    election_type: str,
    office: str,
    territory_code: str,
    territory_level: str,
    metric: str,
    direction: str,
):
    election_type = unquote(election_type)
    office = unquote(office)
    territory_code = unquote(territory_code)
    territory_level = unquote(territory_level)
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
                %s, %s, %s, %s, %s, %s
            );
            """,
            (
                election_type,
                office,
                territory_code,
                territory_level,
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
            content=svg_message("No data found"),
            media_type="image/svg+xml",
        )

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

        color = normalize_color(str(party_rows[0][3] or "#999999"))

        fig.add_trace(
            go.Bar(
                x=years,
                y=values,
                name=party,
                text=labels,
                marker_color=color,
            )
        )

    fig.update_traces(
        texttemplate="%{text}",
        textposition="outside",
        hoverinfo="skip",
        hovertemplate=None,
    )

    direction_label = "rising" if direction == "rise" else "falling"
    metric_label = "seats" if metric == "seats" else "votes"

    fig.update_layout(
        barmode="group",
        title={
            "text": f"Top {direction_label} parties by {metric_label}",
            "x": 0.5,
            "xanchor": "center",
        },
        xaxis_title="Election year",
        yaxis_title="Seats" if metric == "seats" else "Votes",
        showlegend=True,
        margin=dict(l=40, r=20, t=60, b=40),
        **TRANSPARENT_LAYOUT,
    )

    svg = fig.to_image(format="svg").decode("utf-8")

    return Response(content=svg, media_type="image/svg+xml")


@app.get(
    "/distribution/{election_type}/{election_year}/{office}/{territory_code}/{territory_level}/"
)
def distribution_req(
    election_type: str,
    election_year: int,
    office: str,
    territory_code: str,
    territory_level: str,
):
    election_type = unquote(election_type)
    office = unquote(office)
    territory_code = unquote(territory_code)
    territory_level = unquote(territory_level)

    mode = distribution_mode(
        election_type=election_type,
        office=office,
        territory_level=territory_level,
    )

    if mode == "seat_distribution":
        rows = fetch_seat_distribution_rows(
            election_type=election_type,
            election_year=election_year,
            office=office,
            territory_code=territory_code,
            territory_level=territory_level,
        )

        if not rows:
            return Response(
                content=svg_message("No seat distribution found"),
                media_type="image/svg+xml",
            )

        parties = [str(row[0]) for row in rows]
        seats = [int(row[1] or 0) for row in rows]
        colors = [normalize_color(str(row[2] or "#999999")) for row in rows]

        svg = parliament_svg(
            parties=parties,
            seats=seats,
            colors=colors,
            title=f"Seat distribution — {election_type} {election_year}",
        )

        return Response(content=svg, media_type="image/svg+xml")

    if mode == "elected_distribution":
        row = fetch_elected_row(
            election_type=election_type,
            election_year=election_year,
            office=office,
            territory_code=territory_code,
            territory_level=territory_level,
        )

        if not row:
            return Response(
                content=svg_message("No elected party found"),
                media_type="image/svg+xml",
            )

        party = str(row[0])
        votes = int(row[1] or 0)
        color = normalize_color(str(row[2] or "#999999"))

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
        territory_code=territory_code,
        territory_level=territory_level,
    )

    if not rows:
        return Response(
            content=svg_message("No seat distribution found"),
            media_type="image/svg+xml",
        )

    parties = [str(row[0]) for row in rows]
    seats = [int(row[1] or 0) for row in rows]
    colors = [normalize_color(str(row[2] or "#999999")) for row in rows]

    svg = square_bar_svg(
        parties=parties,
        values=seats,
        colors=colors,
        title=f"Party seat distribution — {election_type} {election_year}",
        y_title="Seats",
    )

    return Response(content=svg, media_type="image/svg+xml")


def distribution_mode(
    election_type: str,
    office: str,
    territory_level: str,
) -> str:
    election_type = election_type.upper()
    office = office.upper()
    territory_level = territory_level.lower()

    if election_type == "LEGISLATIVAS" and office == "AR":
        if territory_level == "country":
            return "seat_distribution"
        return "aggregate_distribution"

    if election_type == "AUTARQUICAS" and office == "AM":
        if territory_level == "municipality":
            return "seat_distribution"
        return "aggregate_distribution"

    if election_type == "AUTARQUICAS" and office == "AF":
        if territory_level == "parish":
            return "seat_distribution"
        return "aggregate_distribution"

    if election_type == "AUTARQUICAS" and office == "CM":
        return "elected_distribution"

    return "aggregate_distribution"


def fetch_seat_distribution_rows(
    election_type: str,
    election_year: int,
    office: str,
    territory_code: str,
    territory_level: str,
):
    conn = get_conn()
    cursor = conn.cursor()

    try:
        cursor.execute(
            """
            SELECT
                pe.sigla,
                SUM(COALESCE(sr.seats, 0))::integer AS seats,
                pe.color
            FROM wh.fact_seat_result sr
            JOIN wh.dim_election e
              ON e.election_key = sr.election_key
            JOIN wh.dim_office o
              ON o.office_key = sr.office_key
            JOIN wh.dim_political_entity pe
              ON pe.political_entity_key = sr.political_entity_key
            JOIN wh.dim_territory t
              ON t.territory_key = sr.territory_key
            WHERE e.election_type = %s
              AND e.election_year = %s
              AND o.office_code = %s
              AND (
                    t.territory_code = %s
                    OR t.parent_code = %s
                    OR (
                        %s = 'PT'
                        AND %s = 'country'
                        AND t.territory_level = 'district'
                    )
                  )
              AND COALESCE(sr.seats, 0) > 0
            GROUP BY
                pe.sigla,
                pe.color
            ORDER BY
                seats DESC;
            """,
            (
                election_type,
                election_year,
                office,
                territory_code,
                territory_code,
                territory_code,
                territory_level,
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
    territory_code: str,
    territory_level: str,
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
                %s, %s, %s, %s, %s
            )
            WHERE COALESCE(votes, 0) > 0
            ORDER BY votes DESC
            LIMIT 1;
            """,
            (
                election_type,
                election_year,
                office,
                territory_code,
                territory_level,
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
        return svg_message("No seats found")

    rows = max(3, min(10, int(math.sqrt(total_seats))))
    radii = [0.35 + (i / max(rows - 1, 1)) * 0.65 for i in range(rows)]

    weights = radii
    total_weight = sum(weights)

    points_per_row = [
        max(1, round(total_seats * weight / total_weight)) for weight in weights
    ]

    diff = total_seats - sum(points_per_row)
    points_per_row[-1] += diff

    seat_positions = []

    for radius, count in zip(radii, points_per_row):
        if count <= 1:
            angles = [90]
        else:
            angles = [180 - (180 * i / (count - 1)) for i in range(count)]

        for angle in angles:
            seat_positions.append((radius, angle))

    seat_positions = sorted(
        seat_positions,
        key=lambda item: (item[1], item[0]),
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
                    line=dict(width=1, color="white"),
                ),
                hoverinfo="skip",
            )
        )

    fig.update_layout(
        title={
            "text": title,
            "x": 0.5,
            "xanchor": "center",
        },
        showlegend=True,
        polar=dict(
            bgcolor="white",
            radialaxis=dict(visible=False),
            angularaxis=dict(visible=False),
        ),
        margin=dict(l=20, r=20, t=70, b=20),
        height=600,
        width=900,
    )

    svg = fig.to_image(format="svg").decode("utf-8")

    return svg


def square_bar_svg(
    parties: list[str],
    values: list[int],
    colors: list[str],
    title: str,
    y_title: str,
) -> str:
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
                marker_line_color="white",
            )
        )

    fig.update_traces(
        texttemplate="%{text}",
        textposition="outside",
        hoverinfo="skip",
        hovertemplate=None,
        width=0.65,
    )

    fig.update_layout(
        title={
            "text": title,
            "x": 0.5,
            "xanchor": "center",
        },
        xaxis_title="Party",
        yaxis_title=y_title,
        showlegend=False,
        margin=dict(l=40, r=20, t=70, b=80),
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
                line=dict(width=3, color="white"),
            ),
            text=[party],
            textposition="middle center",
            textfont=dict(
                size=22,
                color="white",
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
            color="#333333",
        ),
    )

    fig.update_layout(
        title={
            "text": title,
            "x": 0.5,
            "xanchor": "center",
        },
        xaxis=dict(
            visible=False,
            range=[-1, 1],
        ),
        yaxis=dict(
            visible=False,
            range=[-1, 1],
        ),
        plot_bgcolor="white",
        paper_bgcolor="white",
        showlegend=False,
        margin=dict(l=20, r=20, t=70, b=20),
        height=420,
        width=600,
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

    return "#999999"


def svg_message(message: str) -> str:
    return f"""
    <svg xmlns="http://www.w3.org/2000/svg" width="900" height="300">
        <rect width="100%" height="100% " fill="white"/>
        <text x="40" y="150" font-size="24" fill="black">{message}</text>
    </svg>
    """
