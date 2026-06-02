from fastapi import FastAPI, Response
import psycopg2
import plotly.graph_objects as go
from urllib.parse import unquote

conn = psycopg2.connect(database="elections", port="5432")

app = FastAPI()


@app.get("/treemap/{election_type}/{election_year}/{office}/{territory_code}")
def treemap_req(
    election_type: str,
    election_year: int,
    office: str,
    territory_code: str
):
    clean_election_type = unquote(election_type)
    clean_office = unquote(office)
    clean_territory_code = unquote(territory_code)

    cursor = conn.cursor()

    cursor.execute("""
        SELECT office_name
        FROM wh.dim_office
        WHERE lower(office_code) = lower(%s)
           OR lower(office_name) = lower(%s)
        LIMIT 1
    """, (clean_office, clean_office))

    row = cursor.fetchone()
    if row:
        clean_office = row[0] 

    cursor.execute(
        """
        SELECT sigla, votes
        FROM wh.results_for_territory_parties(
            %s, %s, %s, %s
        );
        """,
        (clean_election_type,
         election_year,
         clean_office,
         clean_territory_code)
    )

    rows = cursor.fetchall()
    cursor.close()

    labels = [r[0] for r in rows]
    values = [r[1] for r in rows]

    svg = treemap_svg(labels, values)
    return Response(content=svg, media_type="image/svg+xml")


def treemap_svg(labels, values):
    fig = go.Figure(go.Treemap(
        labels=labels,
        parents=[""] * len(labels),
        values=values
    ))

    return fig.to_image(format="svg").decode("utf-8")