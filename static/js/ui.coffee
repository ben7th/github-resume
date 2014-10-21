jQuery ->
  df = new DataFiller()
  scope = df.scope 'github-api', {
    username: 'ben7th'
  }
  scope
    .source 'user', (scope_attrs)->
      "https://api.github.com/users/#{scope_attrs.username}"
    .add_getter 'repos_page_url', (data)->
      "https://api.github.com/users/#{data.name}/repos"

  scope
    .source 'repos', (scope_attrs)->
      "https://api.github.com/users/#{scope_attrs.username}/repos"
    .add_getter 'languages_pie', (data)->
      languages = {}
      for repo in data
        language = repo.language || '未知'
        languages[language] = (languages[language] || 0) + 1

      console.log languages

      # 使用 d3 绘制饼图
      arr = ([k, v] for k, v of languages)
      arr = arr.sort (a, b)-> b[1] - a[1]

      colors = [
        '#111','#222','#333','#444','#555','#666','#777','#888','#999','#aaa'
      ]

      pie = d3.layout.pie().value (d)-> d[1]
      data = pie(arr)

      w = 200
      h = 200
      svg = d3.select(document.body).append('svg').attr('width', w).attr('height', h)

      outer_radius = 100
      inner_radius = 50
      arc = d3.svg.arc()
        .innerRadius(inner_radius)
        .outerRadius(outer_radius)

      arcs = svg
        .selectAll('g.arc')
        .data data
        .enter()
        .append('g')
        .attr('class', 'arc')
        .attr('transform', "translate(#{outer_radius}, #{outer_radius})")

      arcs
        .append 'path'
        .attr 'fill', (d, i)-> colors[i]
        .attr 'd', arc


      # 使用 d3 填充图例
      div = d3.select(document.body)
        .selectAll 'div.language'
        .data arr
        .enter()
        .append 'div'
        .attr 'class', 'language'

      div.append 'div'
        .attr 'class', 'icon'
        .style 'background-color', (d, i)-> colors[i]

      div.append 'div'
        .attr 'class', 'name'
        .text (d)-> "#{d[0]} (#{d[1]})"

      $pie = jQuery '<div>'
        .addClass 'pie-svg'
        .append svg[0]

      $languages = jQuery '<div>'
        .addClass 'languages'
        .append div[0]

      [$pie, $languages]


  $user_info = jQuery('.user-info').addClass 'loading'
  $repo_info = jQuery('.repo-info').addClass 'loading'
  scope.fill jQuery(document.body), ->
    $user_info.removeClass 'loading'
    $repo_info.removeClass 'loading'