from urllib.parse import unquote

import plotly.graph_objects as go
import psycopg2
from fastapi import FastAPI, HTTPException, Response

conn = psycopg2.connect(database="elections", port="5432")

app = FastAPI()

TRANSPARENT_LAYOUT = dict(
    paper_bgcolor="rgba(0,0,0,0)",
    plot_bgcolor="rgba(0,0,0,0)",
)


@app.get("/treemap/{election_type}/{election_year}/{office}/{territory_code}")
def treemap_req(
    election_type: str,
    election_year: int,
    office: str,
    territory_code: str,
):
    election_type = unquote(election_type)
    office = unquote(office)
    territory_code = unquote(territory_code)

    cursor = conn.cursor()

    try:
        cursor.execute(
            """
            SELECT office_name
            FROM wh.dim_office
            WHERE lower(office_code) = lower(%s)
               OR lower(office_name) = lower(%s)
            LIMIT 1
            """,
            (office, office),
        )

        row = cursor.fetchone()

        if row:
            office = row[0]

        cursor.execute(
            """
            SELECT sigla, votes
            FROM wh.results_for_territory_parties(
                %s, %s, %s, %s
            );
            """,
            (
                election_type,
                election_year,
                office,
                territory_code,
            ),
        )

        rows = cursor.fetchall()

        if not rows:
            raise HTTPException(
                status_code=404, detail="No data found for given parameters"
            )

        labels = [r[0] for r in rows]
        values = [r[1] for r in rows]

        svg = treemap_svg(labels, values)

        return Response(content=svg, media_type="image/svg+xml")

    finally:
        cursor.close()


def treemap_svg(labels, values):
    fig = go.Figure(
        go.Treemap(
            labels=labels,
            parents=[""] * len(labels),
            values=values,
        )
    )

    fig.update_layout(**TRANSPARENT_LAYOUT)

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
    cursor = conn.cursor()

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
    cursor.close()

    years = [str(row[0]) for row in rows]
    siglas = [str(row[1]) for row in rows]
    kinds = [str(row[2]) for row in rows]
    votes = [int(row[3] or 0) for row in rows]
    vote_pcts = [float(row[4] or 0) for row in rows]
    seats = [int(row[5] or 0) for row in rows]
    colors = [plotly_color(str(row[6] or "#999999")) for row in rows]

    custom_data = list(zip(siglas, kinds, vote_pcts, seats))

    fig = go.Figure(
        data=[
            go.Bar(
                x=years,
                y=votes,
                text=votes,
                marker_color=colors,
                customdata=custom_data,
                hovertemplate=(
                    "Year: %{x}<br>"
                    "Party/result: %{customdata[0]}<br>"
                    "Kind: %{customdata[1]}<br>"
                    "Votes: %{y}<br>"
                    "Vote %: %{customdata[2]:.2f}%<br>"
                    "Seats: %{customdata[3]}<extra></extra>"
                ),
            )
        ]
    )

    fig.update_traces(
        texttemplate="%{text}",
        textposition="outside",
    )

    fig.update_layout(
        title=f"{party_sigla} over the years",
        xaxis_title="Election year",
        yaxis_title="Votes",
        showlegend=False,
        margin=dict(l=40, r=20, t=60, b=40),
        **TRANSPARENT_LAYOUT,
    )

    svg = fig.to_image(format="svg").decode("utf-8")

    return Response(content=svg, media_type="image/svg+xml")


def plotly_color(color: str) -> str:
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


@app.get(
    "/topgrowing/{election_type}/{office}/{territory_code}/{territory_level}/{metric}/"
)
def topgrowing_req(
    election_type: str,
    office: str,
    territory_code: str,
    territory_level: str,
    metric: str,
):
    cursor = conn.cursor()

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
            growth_value
        FROM wh.top_party_growth(
            %s, %s, %s, %s, %s
        );
        """,
        (
            election_type,
            office,
            territory_code,
            territory_level,
            metric,
        ),
    )

    rows = cursor.fetchall()
    cursor.close()

    if not rows:
        return Response(
            content="""
            <svg xmlns="http://www.w3.org/2000/svg" width="900" height="300">
                <rect width="100%" height="100%" fill="none"/>
                <text x="40" y="150" font-size="24" fill="black">No data found</text>
            </svg>
            """,
            media_type="image/svg+xml",
        )

    years = sorted({str(row[0]) for row in rows})

    parties = []
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

        color = plotly_color(str(party_rows[0][3] or "#999999"))

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
        title=f"Top 4 growing parties by {metric}",
        xaxis_title="Election year",
        yaxis_title="Seats" if metric == "seats" else "Votes",
        showlegend=True,
        margin=dict(l=40, r=20, t=60, b=40),
        **TRANSPARENT_LAYOUT,
    )

    svg = fig.to_image(format="svg").decode("utf-8")

    return Response(content=svg, media_type="image/svg+xml")