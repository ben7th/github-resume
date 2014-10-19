do ->
  df = new DataFiller()

  test 'new DataFiller', ->
    ok df

  scope = df.scope 'github', {
    username: 'ben7th'
  }

  test '声明 scope', ->
    ok df.scope('github')
    equal df.scope('github').attrs['username'], 'ben7th'

  # ------------

  scope_1 = df.scope 'website', {
    domain: 'www.example.com'
    country: 'CHINA'
  }

  test '声明 scope', ->
    deepEqual df.scope('website').attrs, {
      country: 'CHINA'
      domain: 'www.example.com'
    }

  test '获取 scope 集合', ->
    arr = (name for name, scope of df.scopes)
    deepEqual arr.sort(), ['github', 'website']


do ->
  df = new DataFiller()
  scope = df.scope 'github', {
    username: 'ben7th'
  }

  test '方法定义', ->
    ok scope.source

  # 直接声明 url
  scope.source 'users', "https://api.github.com/users"
  # 声明 object
  scope.source 'book', {
    title: '三体'
    price: '23.00'
  }
  # 声明方法
  scope.source 'user', (scope_attrs)->
    "https://api.github.com/users/#{scope_attrs.username}"
  scope.source 'user_book', (scope_attrs)->
    {
      title: "#{scope_attrs.username}'s book"
      price: "free"
    }

  test '声明数据源', ->
    arr = (name for name, source of scope.sources)
    equal arr.length, 4

  test '从数据源取得 scope', ->
    deepEqual scope.source('users').scope, scope
    equal scope.source('users').scope.attrs.username, 'ben7th'

  test '数据源类型', ->
    equal scope.source('users').type, 'URL'
    equal scope.source('book').type, 'OBJECT'
    equal scope.source('user').type, 'FUNCTION'
    equal scope.source('user_book').type, 'FUNCTION'

  asyncTest '异步：加载数据 - 对象', ->
    scope.load 'book', (data)->
      deepEqual data, {
        title: '三体'
        price: '23.00'
      }
      QUnit.start()

  asyncTest '异步：加载数据 - URL', ->
    scope.load 'users', (data)->
      equal data[0].login, 'mojombo'
      equal data[1].login, 'defunkt'
      QUnit.start()

  asyncTest '异步：加载数据 - 方法 - 返回 URL', ->
    scope.load 'user', (data)->
      equal data.login, 'ben7th'
      equal data.id, '322486'
      QUnit.start()

  asyncTest '异步：加载数据 - 方法 - 返回 对象', ->
    scope.load 'user_book', (data)->
      equal data.title, "ben7th's book"
      equal data.price, 'free'
      QUnit.start()

  # -------------------
  $dom0 = jQuery('.area0')

  # asyncTest '异步：填充数据', ->
  #   scope.fill $dom0, ->
  #     equal $dom0.find('span.t1').text(), 'ben7th'
  #     QUnit.start()

  test '扫描数据源', ->
    sources = scope.scan_needed_sources $dom0
    equal sources.length, 1


do ->
  module '数据标记解析'

  test '分析数据标记0', ->
    f = new Field 'user.name'
    equal f.source_name, 'user'
    deepEqual (key for key of f.attrs).sort(), ['name']

  test '分析数据标记1', ->
    f = new Field 'user.name:data-name.avatar_url:src'
    equal f.source_name, 'user'
    deepEqual (key for key of f.attrs).sort(), ['avatar_url', 'name']

  test '分析数据标记2', ->
    f = new Field 'user->created_at$text'
    equal f.source_name, 'user'
    deepEqual (key for key of f.attrs).sort(), ['->created_at']

  test '分析数据标记3', ->
    console.log '-----------'
    f = new Field 'user.name:data-name.avatar_url:src.id:id->created_at:data-time'
    equal f.source_name, 'user'
    deepEqual (key for key of f.attrs).sort(), ['->created_at', 'avatar_url', 'id', 'name']
    console.log '------------'


  test 'Field._split_parts', ->
    parts = Field._split_parts '.name:data-name.avatar_url:src.id:id->created_at:data-time'
    deepEqual parts, [
      '.name:data-name'
      '.avatar_url:src'
      '.id:id'
      '->created_at:data-time'
    ]

    parts = Field._split_parts '.name:a->time:b->range:c.age.birthday:d'
    deepEqual parts, [
      '.name:a'
      '->time:b'
      '->range:c'
      '.age'
      '.birthday:d'
    ]

    parts = Field._split_parts '.name:a ->time:b ->range:c .age .birthday:d'
    deepEqual parts, [
      '.name:a'
      '->time:b'
      '->range:c'
      '.age'
      '.birthday:d'
    ]