BASE_URL = 'http://192.168.1.26:4567/github?path='

API = 
  request_user_info : (user_name, func)->
    url = "https://api.github.com/users/#{user_name}"
    jQuery.getJSON url, func

  # TODO 获取版本库时应该考虑数据分页
  request_user_repos: (user_name, func)->
    url = "https://api.github.com/users/#{user_name}/repos"
    jQuery.getJSON url, func


class GithubResume
  constructor: (@$el)->
    @$user_info = @$el.find('.user-info')
    @$user_repos = @$el.find('.user-repos')

    @bind_events()

  bind_events: ->
    # 设置输入框事件
    @$el.delegate '.user-name-ipt a.ok', 'click', =>
      user_name = jQuery.trim jQuery('input.user-name').val()
      if user_name.length
        @$user_info.addClass 'loading'
        API.request_user_info user_name, (data)=>
          @set_user_info data

          @$user_repos.addClass 'loading'
          API.request_user_repos user_name, (data)=>
            @set_user_repos data

  set_user_info: (data)->
    @$user_info.removeClass 'loading'
    @$user_info.haml [
      # 头像
      ['%img.avatar', {'src': data.avatar_url}]

      # 基础统计信息
      ['.base-info', 
        "自 #{data.created_at} 以来，共创建了 #{data.public_repos} 个版本库"
      ]
    ]

  set_user_repos: (data)->
    @$user_repos.removeClass 'loading'
    languages = {}

    for repo in data
      name = repo.name
      html_url = repo.html_url
      fork = repo.fork
      language = repo.language

      if not languages[language]
        languages[language] = 1
      else
        languages[language] += 1

      # $repo = jQuery('<div>').addClass('repo').haml [
      #   ['.name', name]
      #   ['.html-url', html_url]
      #   ['.fork', fork]
      #   ['.language', language]
      # ]
      # .appendTo @$user_repos

    # 调用 d3 画饼图
    arr = for l of languages
      languages[l]

    pie = d3.layout.pie()
    data = pie(arr)
    console.log data

    svg = d3.select('.user-repos').append('svg').attr('width', 200).attr('height', 200)

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

    # color = d3.scale.category10()
    colors = [
      '#111'
      '#222'
      '#333'
      '#444'
      '#555'
      '#666'
      '#777'
      '#888'
      '#999'
      '#aaa'
    ]

    arcs
      .append 'path'
      .attr 'fill', (d, i)->
        return colors[i]
      .attr 'd', arc



jQuery ->
  new GithubResume jQuery('.page-content')