BASE_URL = 'http://192.168.1.26:4567/github?path='

API = 
  user_url: (user_name)->
    "https://api.github.com/users/#{user_name}"

  # TODO 获取版本库时应该考虑数据分页
  repos_url: (user_name)->
    "https://api.github.com/users/#{user_name}/repos"


# 数据填充对象
class DataFiller
  constructor: (@$dom, @key, @attrs)->

  fill: (data)->
    if @key[0...2] is '->'
      # 以 -> 声明的值调用方法
      f = DataFiller[@key[2..-1]] || => 
        console.log "没有定义数据获取方法 #{@key[2..-1]}"
      value = f(data, @$dom)

    else
      value = data[@key]

    if @attrs.length is 0
      @$dom.text value
      return

    for attr in @attrs
      if attr is 'link'
        $a = jQuery('<a>')
          .attr 'href', value
          .attr 'target', '_blank'
          .text value
        @$dom.html $a

      else if attr is 'html'
        @$dom.html value

      else if attr is 'null'
        # nothing

      else 
        @$dom.attr attr, value

  # 暂时先把自定义的属性获取方法都写成 DataFiller 的类方法
  @repos_page_url: (data)->
    "https://github.com/#{data.login}?tab=repositories"

  @repo_pie: (data, $dom)->
    languages = {}
    for repo in data
      language = repo.language || '未知'
      languages[language] = (languages[language] || 0) + 1

    # 使用 d3 绘制饼图
    arr = ([k, v] for k, v of languages)
    arr = arr.sort (a, b)-> b[1] - a[1]

    pie = d3.layout.pie().value (d)-> d[1]
    data = pie(arr)

    w = 200
    h = 200
    svg = d3.select($dom.find('.pie-svg')[0]).append('svg').attr('width', w).attr('height', h)

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


    colors = [
      '#111','#222','#333','#444','#555','#666','#777','#888','#999','#aaa'
    ]

    arcs
      .append 'path'
      .attr 'fill', (d, i)-> colors[i]
      .attr 'd', arc


    # 使用 d3 填充图例
    div = d3.select($dom.find('.languages')[0])
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


class JsonDataLoader
  constructor: (@$el)->
    @init_fills()
    @urls = {}

    console.log @fillers

  # 扫描整个页面上的元素，记录需要加载数据的dom
  init_fills: ->
    @fillers = {}
    jQuery('[pl]').each (i, dom)=>
      $dom = jQuery(dom)
      pl = $dom.attr 'pl'

      dataset_name = pl.split('.')[0]
      key_and_attrs = pl.split('.')[1]
      key = key_and_attrs.split('@')[0]
      attrs = key_and_attrs.split('@')[1 .. -1]

      @fillers[dataset_name] ?= []
      @fillers[dataset_name].push new DataFiller($dom, key, attrs)



  # 注册一组数据，并为该组数据指定获取 url
  # 获得数据后，根据元素上指定的 pl 值去加载数据到 dom
  add_dataset: (dataset_name, url_or_urls)->
    @urls[dataset_name] = url_or_urls

  load_data: (dataset_name, options = {})->
    url = @urls[dataset_name]
    options.before ?= ->{}
    options.done ?= ->{}

    @show_loading dataset_name

    # 一组 url
    if url instanceof Array
      $item = jQuery("[pl='#{dataset_name}.item']")
      $parent = $item.parent()
      $item.remove()

      for u in url
        jQuery.getJSON u, (data)=>
          $_item = $item.clone().appendTo $parent
          $_item.find("[pleach]").each (i, dom)->
            $dom = jQuery(dom)
            $dom.text data[$dom.attr 'pleach']


      return
    
    # 一个url
    options.before()
    jQuery.getJSON url, (data)=>
      for filler in @fillers[dataset_name] || []
        filler.fill data
      options.done(data)


  # 凡是包含 dataset_name 的数据填充对象的容器
  # 都显示 loading 样式
  show_loading: (dataset_name)->
    for filler in @fillers[dataset_name] || []
      filler.$dom.closest '.data-piece'
        .addClass 'loading'



class GithubResume
  constructor: (@$el)->
    @$user_info = jQuery('.user-name-location')
    @$repo_base = jQuery('.repo-base')


  load: (user_name)->
    @user_name = user_name
    
    @dataloader = new JsonDataLoader

    @load_user()

  load_user: ->
    @dataloader.add_dataset 'user', API.user_url @user_name
    @dataloader.load_data 'user', {
      done: =>
        @$user_info.removeClass 'loading'
        @load_repos()
    }

  load_repos: ->
    @dataloader.add_dataset 'repos', API.repos_url @user_name
    @dataloader.load_data 'repos', {
      done: (data)=>
        @$repo_base.removeClass 'loading'

        repo_urls = for repo in data
          url = repo.url

        @dataloader.add_dataset 'repos-list', repo_urls
        @dataloader.load_data 'repos-list'
    }


jQuery ->
  gr = new GithubResume jQuery('.page-content')
  gr.load 'ben7th'