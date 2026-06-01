from fastapi import FastAPI, Response
import psycopg2
import plotly.graph_objects as go

conn = psycopg2.connect(database="elections", port="5432")

app = FastAPI()


@app.get("/treemap/{election_type}/{election_year}/{office}/{territory_code}/{territory_level}")
def treemap_req(election_type:   str, 
                election_year:   int, 
                office:          str, 
                territory_code:  str, 
                territory_level: str):

    cursor = conn.cursor() 

    cursor.execute(
        """
        SELECT sigla, votes
        FROM wh.results_for_territory_parties(
            %s, %s, %s, %s, %s
        );
        """,
        ( election_type, 
          election_year, 
          office, 
          territory_code, 
          territory_level )
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

    svg_text = fig.to_image(format="svg").decode("utf-8")
    return svg_text