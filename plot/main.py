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
                %s::text, %s::integer, %s::text, %s::bigint
            );
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
            content=svg_message("No data found"),
            media_type="image/svg+xml",
        )

    labels = [str(r[0]) for r in rows]
    values = [int(r[1] or 0) for r in rows]
    colors = [normalize_color(str(r[2] or "#999999")) for r in rows]

    svg = treemap_svg(labels, values, colors)

    return Response(content=svg, media_type="image/svg+xml")


def treemap_svg(labels: list[str], values: list[int], colors: list[str]) -> str:
    fig = go.Figure(
        go.Treemap(
            labels=labels,
            parents=[""] * len(labels),
            values=values,
            marker=dict(colors=colors),
        )
    )

    fig.update_layout(
        margin=dict(l=0, r=0, t=0, b=0),
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
    election_type = unquote(election_type)
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
                %s::text, %s::text, %s::bigint, %s::text, %s::text
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
            content=svg_message("No data found"),
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
            content=svg_message("Territory not found"),
            media_type="image/svg+xml",
        )

    territory_code = territory_info["territory_code"]
    territory_level = territory_info["territory_level"]

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
            territory_key=territory_key,
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
        territory_key=territory_key,
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
            WITH selected AS (
                SELECT
                    e.election_key,
                    e.election_type,
                    e.election_year,
                    o.office_key,
                    o.office_code
                FROM wh.dim_election e
                JOIN wh.dim_office o
                  ON (
                        lower(o.office_code) = lower(%s::text)
                        OR lower(o.office_name) = lower(%s::text)
                     )
                WHERE lower(e.election_type) = lower(%s::text)
                  AND e.election_year = %s::integer
                LIMIT 1
            ),

            target AS (
                SELECT
                    t.territory_key,
                    t.territory_code,
                    t.territory_level,
                    t.parent_code,
                    parent.territory_code AS parent_territory_code,
                    parent.territory_level AS parent_territory_level,
                    grandparent.territory_code AS grandparent_territory_code,
                    grandparent.territory_level AS grandparent_territory_level
                FROM wh.dim_territory t
                LEFT JOIN wh.dim_territory parent
                  ON parent.territory_code = t.parent_code
                LEFT JOIN wh.dim_territory grandparent
                  ON grandparent.territory_code = parent.parent_code
                WHERE t.territory_key = %s::bigint
                LIMIT 1
            ),

            seat_territories AS (
                SELECT
                    vt.territory_key
                FROM selected s
                JOIN target tg ON true
                JOIN wh.dim_territory vt
                  ON vt.territory_level = 'district'
                 AND (
                        tg.territory_level = 'country'
                        OR (
                            tg.territory_level = 'district'
                            AND vt.territory_code = tg.territory_code
                        )
                        OR (
                            tg.territory_level = 'municipality'
                            AND vt.territory_code = tg.parent_code
                        )
                        OR (
                            tg.territory_level = 'parish'
                            AND vt.territory_code = tg.grandparent_territory_code
                        )
                     )
                WHERE lower(s.election_type) = 'legislativas'
                   OR upper(s.office_code) = 'AR'

                UNION ALL

                SELECT
                    vt.territory_key
                FROM selected s
                JOIN target tg ON true
                JOIN wh.dim_territory vt
                  ON vt.territory_level = 'municipality'
                 AND (
                        tg.territory_level = 'country'
                        OR (
                            tg.territory_level = 'district'
                            AND vt.parent_code = tg.territory_code
                        )
                        OR (
                            tg.territory_level = 'municipality'
                            AND vt.territory_code = tg.territory_code
                        )
                        OR (
                            tg.territory_level = 'parish'
                            AND vt.territory_code = tg.parent_code
                        )
                     )
                WHERE upper(s.office_code) IN ('AM', 'CM')

                UNION ALL

                SELECT
                    vt.territory_key
                FROM selected s
                JOIN target tg ON true
                JOIN wh.dim_territory vt
                  ON vt.territory_level = 'parish'
                LEFT JOIN wh.dim_territory parent_municipality
                  ON parent_municipality.territory_code = vt.parent_code
                 AND parent_municipality.territory_level = 'municipality'
                WHERE upper(s.office_code) = 'AF'
                  AND (
                        tg.territory_level = 'country'
                        OR (
                            tg.territory_level = 'district'
                            AND parent_municipality.parent_code = tg.territory_code
                        )
                        OR (
                            tg.territory_level = 'municipality'
                            AND vt.parent_code = tg.territory_code
                        )
                        OR (
                            tg.territory_level = 'parish'
                            AND vt.territory_code = tg.territory_code
                        )
                      )

                UNION ALL

                SELECT
                    vt.territory_key
                FROM selected s
                JOIN wh.dim_territory vt
                  ON vt.territory_level = 'country'
                 AND vt.territory_code = 'PT'
                WHERE upper(s.office_code) IN ('PR', 'PE')
            )

            SELECT
                pe.sigla,
                SUM(COALESCE(sr.seats, 0))::integer AS seats,
                pe.color
            FROM selected s
            JOIN seat_territories st
              ON true
            JOIN wh.fact_seat_result sr
              ON sr.election_key = s.election_key
             AND sr.office_key = s.office_key
             AND sr.territory_key = st.territory_key
            JOIN wh.dim_political_entity pe
              ON pe.political_entity_key = sr.political_entity_key
            WHERE COALESCE(sr.seats, 0) > 0
            GROUP BY
                pe.sigla,
                pe.color
            ORDER BY
                wh.political_entity_order(pe.sigla),
                seats DESC,
                pe.sigla ASC;
            """,
            (
                office,
                office,
                election_type,
                election_year,
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
                %s::text, %s::integer, %s::text, %s::bigint
            )
            WHERE COALESCE(votes, 0) > 0
            ORDER BY votes DESC
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

    return fig.to_image(format="svg").decode("utf-8")


def square_bar_svg(
    parties: list[str],
    values: list[int],
    colors: list[str],
    title: str,
    y_title: str,
) -> str:
    items = sorted(
        zip(parties, values, colors),
        key=lambda item: item[1],
        reverse=True,
    )[:20]

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
        <rect width="100%" height="100%" fill="white"/>
        <text x="40" y="150" font-size="24" fill="black">{message}</text>
    </svg>
    """
