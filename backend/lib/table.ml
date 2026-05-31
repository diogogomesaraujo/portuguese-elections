open Caqti_request.Infix

module Table = struct
  type t =
    { header : string list
    ; data : string list list
    }

  let generic =
    let query =
      "
      SELECT
          parish.territory_name AS parish,
          municipality.territory_name AS municipality,
          district.territory_name AS district,
          country.territory_name AS country
      FROM wh.dim_territory parish
      LEFT JOIN wh.dim_territory municipality
        ON municipality.territory_code = parish.parent_code
       AND municipality.territory_level = 'municipality'
      LEFT JOIN wh.dim_territory district
        ON district.territory_code = municipality.parent_code
       AND district.territory_level = 'district'
      LEFT JOIN wh.dim_territory country
        ON country.territory_code = district.parent_code
       AND country.territory_level = 'country'
      WHERE parish.territory_level = 'parish'
      ORDER BY
          district.territory_name,
          municipality.territory_name,
          parish.territory_name;
      "
    in
    ( [ "Freguesia"; "Município"; "Distrito/Ilha"; "País" ]
    , Caqti_type.(unit ->* t4 string string string string) query )
end
