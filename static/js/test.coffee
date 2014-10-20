do ->
  QUnit.module 'scope 操作'

  df = new DataFiller()

  QUnit.test 'new DataFiller', (assert)->
    assert.ok df

  scope = df.scope 'github', {
    username: 'ben7th'
  }

  QUnit.test '声明 scope', (assert)->
    assert.ok df.scope('github')
    assert.equal df.scope('github').attrs['username'], 'ben7th'

  # ------------

  scope_1 = df.scope 'website', {
    domain: 'www.example.com'
    country: 'CHINA'
  }

  QUnit.test '声明 scope', (assert)->
    assert.deepEqual df.scope('website').attrs, {
      country: 'CHINA'
      domain: 'www.example.com'
    }

  QUnit.test '获取 scope 集合', (assert)->
    arr = (name for name, scope of df.scopes)
    assert.deepEqual arr.sort(), ['github', 'website']


do ->
  QUnit.module '数据源操作'

  df = new DataFiller()
  scope = df.scope 'github', {
    username: 'ben7th'
  }

  QUnit.test '方法定义', (assert)->
    assert.ok scope.source

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
    arr = (name for name, source of scope.sources)
    assert.equal arr.length, 4

  QUnit.test '从数据源取得 scope', (assert)->
    deepEqual scope.source('users').scope, scope
    equal scope.source('users').scope.attrs.username, 'ben7th'

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
      assert.equal data.title, "ben7th's book"
      assert.equal data.price, 'free'
      QUnit.start()

  # -------------------
  QUnit.module '数据填充操作'

  $dom0 = jQuery('.area0')

  QUnit.asyncTest '异步：填充数据', (assert)->
    scope.fill $dom0, ->
      assert.equal $dom0.find('span.t1').text(), 'ben7th'
      assert.equal $dom0.find('span.t2').text(), '322486'
      assert.equal $dom0.find('span.t3').data('type'), 'User'
      QUnit.start()

  QUnit.test '扫描数据源', (assert)->
    sources = scope.scan_needed_sources $dom0
    assert.equal sources.length, 1
    assert.equal sources[0].name, 'user'


do ->
  module '数据标记解析'

  QUnit.assert.has_keys = (value, expected, message)->
    autual = (key for key of value).sort()
    return this.deepEqual autual, expected.sort()


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