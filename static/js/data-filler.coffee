class Source
  constructor: (@name, @from)->
    t = typeof @from
    if t is 'string'
      @type = 'URL'
    else if t is 'object'
      @type = 'OBJECT'
    else if t is 'function'
      @type = 'FUNCTION'

  load: (func)->
    if @type is 'OBJECT'
      func @from
      return @

    if @type is 'URL'
      jQuery.getJSON @from, func
      return @

    if @type is 'FUNCTION'
      from = @from(@scope.attrs)
      if (typeof from) is 'string'
        jQuery.getJSON from, func
        return @

      if (typeof from) is 'object'
        func from
        return @


class Scope
  constructor: (@name)->
    @attrs = {}
    @sources = {}

  set: (key, value)->
    @attrs[key] = value

  source: (source_name, from)->
    source = @sources[source_name] ?= new Source source_name, from
    source.scope = @

    return source

  # 加载数据，然后执行传入的回调方法
  load: (source_name, func)->
    source = @sources[source_name]
    source.load func

  # 传入一个 dom 对象或 jQuery 对象
  # 根据规则进行数据填充
  # 之后调用回调方法
  fill: (dom, func)->
    $dom = jQuery(dom)
    sources = @scan_needed_sources $dom
    dom_sources = $dom.data 'sources'

    l = sources.length
    for source in sources
      source.load (data)->
        for field in dom_sources[source.name]
          field.fill data

        l--
        func() if l == 0

  # 扫描 dom，确定需要 load 哪些数据源
  # 返回包含数据源对象的数组
  scan_needed_sources: ($dom)->
    sources = []
    $dom.find('[df]').each (i, mark)=>
      $mark = jQuery(mark)
      field = Field.from_dom $mark
      sources[field.source_name] ?= []
      sources[field.source_name].push field
    $dom.data 'sources', sources

    return ( @source source_name for source_name of sources)


class Field
  @_split_parts: (string)->
    for s in string.match /(->|\.){0,1}[^->.]+(-(?!>)){0,1}[^->.]+/g
      s.trim()

  @_split_targets: (string)->
    for s in string.match /[:$]{0,1}[^:$]+/g
      s.trim()

  @from_dom: ($mark)->
    field_string = $mark.attr('df')
    field = new Field field_string
    field.$mark = $mark
    field

  constructor: (@field_string)->
    # 提取 source_name
    splits = Field._split_parts @field_string
    @source_name = splits[0]

    # 提取 attrs
    splits_1 = splits[1 .. -1]
    @attrs = {}
    for part in splits_1
      arr = Field._split_targets part
      attr = arr[0].replace('.', '')
      targets = arr[1 .. -1]
      @attrs[attr] = targets

  # data 是传入的数据集
  fill: (data)->
    for key, targets of @attrs
      data_value = data[key]

      # 默认填充 $text
      if targets.length is 0
        @$mark.text data_value
        continue
      
      # 遍历
      for target in targets
        if target[0] is '$'
          switch target
            when '$text'
              @$mark.text data_value

        if target[0] is ':'
          @$mark.attr target[1 .. -1], data_value





class DataFiller
  constructor: ->
    @scopes = {}

  scope: (scope_name, attrs)->
    scope = @scopes[scope_name] ?= new Scope scope_name
    
    if attrs?
      for key, value of attrs
        scope.set key, value

    return scope


window.DataFiller = DataFiller
window.Field = Field