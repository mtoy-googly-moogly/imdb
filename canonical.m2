// imdb genre_matrix --------------------------------------------------------
source: _movies is duckdb('data/titles.parquet') def { primary_key: tconst }
source: movies is _movies def {
  measure:
    title_count is count(distinct tconst)
    total_ratings is sum(ratings.numVotes/1000.0)
    percent_of_titles is title_count/all(title_count)* 100

  query: genre_matrix is
    def {
      join_many: x
        is _movies -> select { group_by: tconst, genres.value }
        on tconst = x.tconst
    } ->  select {
      where: genres.value != x.value
      group_by: genre1 is genres.value
      aggregate:  title_count
      nest: genre is select {
        group_by: genre1 is genres.value genre2 is x.value
        nest: by_title_list is select {
          group_by: primaryTitle, ratings.numVotes
          order_by: 2 desc
          limit: 10
        }
      }
    }
}

run: movies.genre_matrix

// names ----------------------------------------------
source: names_table is duckdb('data/usa_names.parquet') def {
  measure: population is `number`.sum()
  dimension: decade is floor(`year`/10)*10

  query: by_name is select { group_by: name aggreate: population limit: 10 }
  query: by_state is select { group_by: state  aggregate: population }
  query: by_gender is select { group_by: gender aggregate: population }
  query: by_decade is select {
    group_by: decade
    aggregate: population
    order_by: 1 asc
  }
  query: name_as_pct_of_pop is
    select { nest: by_name aggregate: population }
    -> select {
      columns:
        by_name.*,
        percentage_of_population is by_name.population / population * 100
      order_by: 3 desc
      limit: 10
    }
  query: male_names is by_name mod { where: gender = 'M'}
  query: female_names is by_name mod { where: gender = 'F'}
  query: top_names_by_state_ea_gender is by_state mod {
    nest: male_names, female_names
    limit: 10
  }
  query: name_dashboard is by_name mod {
    nest: by_decade by_state by_gender
    limit: 10
  }
}

query: j_names is names_table.name_dashboard mod { where: name ~ r'J'}
