class Source
  constructor: (@name, @from = {})->
    @getters = {}

    t = typeof @from
    if t is 'string'
      @type = 'URL'
    else if t is 'object'
      @type = 'OBJECT'
    else if t is 'function'
      @type = 'FUNCTION'

  load: (func)->
    if @type is 'OBJECT'
      @data = @from
      @loaded = true
      func @data
      return @

    if @type is 'URL'
      jQuery.getJSON @from, (data)=>
        @data = data
        @loaded = true
        func @data
      return @

    if @type is 'FUNCTION'
      from = @from(@scope.attrs)
      if (typeof from) is 'string'
        jQuery.getJSON from, (data)=>
          @data = data
          @loaded = true
          func @data
        return @

      if (typeof from) is 'object'
        @data = from
        @loaded = true
        func @data
        return @

  add_getter: (getter_name, func)->
    @getters[getter_name] = func
    return @



class Scope
  constructor: (@name)->
    @attrs = {}
    @sources = {}

  set: (key, value)->
    @attrs[key] = value

  source: (source_name, from)->
    if not @sources[source_name]?
      console.log "尝试在 #{@name} 获取未定义的数据源 #{source_name}" if not from?
      @sources[source_name] = new Source source_name, from

    source = @sources[source_name]
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
    arr = (value for key, value of sources)

    # console.log arr.map (i)-> i.source.name

    count = arr.length
    for item in arr
      do ->
        source = item.source
        fields = item.fields
        source.load (data)->
          for field in fields
            field.fill data, source
          count--
          func() if count is 0

  # 扫描 dom，确定需要 load 哪些数据源
  # 返回包含数据源对象的数组
  scan_needed_sources: ($dom)->
    sources = {}

    $dom.find('[df]').each (i, mark)=>
      $mark = jQuery(mark)
      field = Field.from_dom $mark
      source_name = field.source_name

      if sources[source_name]?
        sources[source_name].fields.push field
      else
        sources[source_name] = {
          source: @source source_name
          fields: [field]
        }

    return sources

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
  # source 是传入的数据集注册对象
  fill: (data, source)->
    for key, targets of @attrs
      data_value = @_data_value data, key, source

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
            when '$html'
              @$mark.html data_value

        if target[0] is ':'
          @$mark.attr target[1 .. -1], data_value


  _data_value: (data, key, source)->
    if key[0 .. 1] is '->'
      # 调用注册的自定义方法
      getter_name = key[2 .. -1]
      if source.getters[getter_name]?
        return source.getters[getter_name](data)
      else
        console.log "数据源 #{source.name} 上未定义 #{getter_name} getter."
    else
      # 访问一般属性
      return data[key]




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