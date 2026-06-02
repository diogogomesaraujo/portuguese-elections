from urllib.parse import unquote

import plotly.graph_objects as go
import psycopg2
from fastapi import FastAPI, Response

app = FastAPI()


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
    "/partygrowth/{election_type}/{office}/{territory_code}/{territory_level}/{party_sigla}/"
)
def partygrowth_req(
    election_type: str,
    office: str,
    territory_code: str,
    territory_level: str,
    party_sigla: str,
):
    election_type = unquote(election_type)
    office = unquote(office)
    territory_code = unquote(territory_code)
    territory_level = unquote(territory_level)
    party_sigla = unquote(party_sigla)

    conn = get_conn()
    cursor = conn.cursor()

    try:
        cursor.execute(
            """
            SELECT
                election_year,
                result_sigla,
                result_kind,
                votes,
                vote_pct,
                seats,
                chart_color
            FROM wh.party_over_years(
                %s, %s, %s, %s, %s
            );
            """,
            (
                election_type,
                office,
                territory_code,
                territory_level,
                party_sigla,
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

    years = [str(row[0]) for row in rows]
    votes = [int(row[3] or 0) for row in rows]
    colors = [normalize_color(str(row[6] or "#999999")) for row in rows]

    fig = go.Figure(
        data=[
            go.Bar(
                x=years,
                y=votes,
                text=votes,
                marker_color=colors,
            )
        ]
    )

    fig.update_traces(
        texttemplate="%{text}",
        textposition="outside",
        hoverinfo="skip",
        hovertemplate=None,
    )

    fig.update_layout(
        title=f"{party_sigla} over the years",
        xaxis_title="Election year",
        yaxis_title="Votes",
        showlegend=False,
        margin=dict(l=40, r=20, t=60, b=40),
    )

    svg = fig.to_image(format="svg").decode("utf-8")

    return Response(content=svg, media_type="image/svg+xml")


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

    fig.update_layout(
        barmode="group",
        title=f"Top 4 party {direction} by {metric}",
        xaxis_title="Election year",
        yaxis_title="Seats" if metric == "seats" else "Votes",
        showlegend=True,
        margin=dict(l=40, r=20, t=60, b=40),
    )

    svg = fig.to_image(format="svg").decode("utf-8")

    return Response(content=svg, media_type="image/svg+xml")


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
