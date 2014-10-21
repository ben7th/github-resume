QUnit.assert.has_keys = (value, expected, message)->
  autual = (key for key of value).sort()
  return this.deepEqual autual, expected.sort()

do ->
  QUnit.module 'scope 操作'

  df = new DataFiller()

  QUnit.test '创建一个新的 DataFiller 对象', (assert)->
    assert.ok df

  # -----------------------

  scope = df.scope 'github', {
    username: 'ben7th'
  }

  QUnit.test '声明一个 scope，并设置 scope 变量', (assert)->
    assert.ok df.scope('github')
    assert.equal df.scope('github').attrs['username'], 'ben7th'

  # -----------------------

  scope_1 = df.scope 'website', {
    domain: 'www.example.com'
    country: 'CHINA'
  }

  QUnit.test '声明另一个 scope', (assert)->
    assert.deepEqual df.scope('website').attrs, {
      country: 'CHINA'
      domain: 'www.example.com'
    }

  QUnit.test '获取 DataFiller 对象上的 scope 集合', (assert)->
    assert.has_keys df.scopes, ['github', 'website']


do ->
  QUnit.module '数据源操作'

  # 先初始化一个 DataFiller 对象
  # 再注册一个 scope

  df = new DataFiller()
  scope = df.scope 'github', {
    username: 'ben7th'
  }

  QUnit.test '方法定义', (assert)->
    assert.ok scope.source

  # 可以以三种方式注册数据源：声明 url，声明 object，声明方法

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

  QUnit.test '声明数据源', (assert)->
    assert.has_keys scope.sources, ['users', 'book', 'user', 'user_book']

  QUnit.test '从数据源取得 scope', (assert)->
    s = scope.source('users').scope
    deepEqual s, scope
    equal s.attrs.username, 'ben7th'

  QUnit.test '数据源类型', (assert)->
    assert.equal scope.source('users').type, 'URL'
    assert.equal scope.source('book').type, 'OBJECT'
    assert.equal scope.source('user').type, 'FUNCTION'
    assert.equal scope.source('user_book').type, 'FUNCTION'

  QUnit.asyncTest '异步：加载数据 - 对象', (assert)->
    scope.load 'book', (data)->
      assert.deepEqual data, {
        title: '三体'
        price: '23.00'
      }
      QUnit.start()

  QUnit.asyncTest '异步：加载数据 - URL', (assert)->
    scope.load 'users', (data)->
      assert.equal data[0].login, 'mojombo'
      assert.equal data[1].login, 'defunkt'
      QUnit.start()

  QUnit.asyncTest '异步：加载数据 - 方法 - 返回 URL', (assert)->
    scope.load 'user', (data)->
      assert.equal data.login, 'ben7th'
      assert.equal data.id, '322486'
      QUnit.start()

  QUnit.asyncTest '异步：加载数据 - 方法 - 返回 对象', (assert)->
    scope.load 'user_book', (data)->
      console.log data
      assert.equal data.title, "ben7th's book"
      assert.equal data.price, 'free'
      QUnit.start()

  # -------------------
  QUnit.module '数据填充操作'

  $dom0 = jQuery('.area0')

  QUnit.test '扫描数据源', (assert)->
    sources = scope.scan_needed_sources $dom0
    assert.has_keys sources, ['user']

  QUnit.asyncTest '异步：填充数据', (assert)->
    scope.fill $dom0, ->
      assert.equal $dom0.find('span.t1').text(), 'ben7th'
      assert.equal $dom0.find('span.t2').text(), '322486'
      assert.equal $dom0.find('span.t3').data('type'), 'User'
      QUnit.start()

  scope.sources['user']
    .add_getter 'repos_page_url', (data)->
      "https://api.github.com/users/#{data.name}/repos"
    .add_getter 'location_html', (data)->
      $html = jQuery("<div><i class='fa fa-map-marker'></i>#{data.location}</div>")

  QUnit.asyncTest '异步：填充数据', (assert)->
    $dom1 = jQuery('.area1')
    scope.fill $dom1, ->
      assert.ok $dom1.find('img.t4').attr 'src'
      assert.equal $dom1.find('a.t5').attr('src'), "https://api.github.com/users/ben7th/repos"
      assert.ok $dom1.find('.t6').find('i').length > 0
      QUnit.start()


  QUnit.test '扫描包含多个数据源的dom', (assert)->
    $dom2 = jQuery('.area2')
    sources = scope.scan_needed_sources $dom2
    assert.has_keys sources, ['user', 'user_book']


  QUnit.asyncTest '异步：填充来自多个数据源的数据', (assert)->
    $dom2 = jQuery('.area2')
    scope.fill $dom2, ->
      assert.equal $dom2.find('.t7').text(), 'ben7th'
      assert.equal $dom2.find('.t8').text(), "ben7th's book"
      QUnit.start()


do ->
  module '数据标记解析'

  QUnit.test '分析数据标记0', (assert)->
    f = new Field 'user.name'
    assert.equal f.source_name, 'user'
    assert.has_keys f.attrs, ['name']

  QUnit.test '分析数据标记1', (assert)->
    f = new Field 'user.name:data-name.avatar_url:src'
    assert.equal f.source_name, 'user'
    assert.has_keys f.attrs, ['avatar_url', 'name']
    assert.deepEqual f.attrs['avatar_url'], [':src']
    assert.deepEqual f.attrs['name'], [':data-name']

  QUnit.test '分析数据标记2', (assert)->
    f = new Field 'user->created_at$text'
    assert.equal f.source_name, 'user'
    assert.has_keys f.attrs, ['->created_at']
    assert.deepEqual f.attrs['->created_at'], ['$text']

  QUnit.test '分析数据标记3', (assert)->
    f = new Field 'user .name:data-name .avatar_url:src .id:id ->created_at:data-time'
    assert.equal f.source_name, 'user'
    assert.has_keys f.attrs, ['->created_at', 'avatar_url', 'id', 'name']


  QUnit.test 'Field._split_parts', (assert)->
    parts = Field._split_parts '.name:data-name.avatar_url:src.id:id->created_at:data-time'
    assert.deepEqual parts, [
      '.name:data-name'
      '.avatar_url:src'
      '.id:id'
      '->created_at:data-time'
    ]

    parts = Field._split_parts '.name:a->time:b->range:c.age.birthday:d'
    assert.deepEqual parts, [
      '.name:a'
      '->time:b'
      '->range:c'
      '.age'
      '.birthday:d'
    ]

    parts = Field._split_parts '.name:a ->time:b ->range:c .age .birthday:d'
    assert.deepEqual parts, [
      '.name:a'
      '->time:b'
      '->range:c'
      '.age'
      '.birthday:d'
    ]

  QUnit.test 'Field._split_targets', (assert)->
    targets = Field._split_targets '.name:a$text'
    assert.deepEqual targets, [
      '.name', ':a', '$text'
    ]