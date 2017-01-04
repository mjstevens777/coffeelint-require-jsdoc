chai = require 'chai'
chai.should()

Linter = require '..'
compiler = require 'coffee-script'

class Parent
  constructor: (linter, opts) ->
    config = {}
    for key of linter.rule
      config[key] = linter.rule[key]
    for key of opts
      config[key] = opts[key]
    @config = {}
    @config[linter.rule.name] = config
    linter.errors = []

  createError: (opts) ->
    return opts

lintText = (text, config={}) ->
  nodes = compiler.nodes(text)
  linter = new Linter
  parent = new Parent(linter, config)
  linter.lintAST(nodes, parent)
  return linter.errors


describe 'Linter', ->
  it 'should pass a valid file', ->
    errors = lintText """
      ###*
      # @class A
      ###
      class A
        ###*
        # @property prop
        ###
        prop: 'a'

        ###*
        # @method meth
        ###
        meth: ->
          return
    """
    errors.should.have.lengthOf 0

  context 'class', ->
    it 'should catch a missing docstring', ->
      errors = lintText """
        class A
          ###*
          # @property prop
          ###
          prop: 'a'
      """
      errors.should.have.lengthOf 1
      errors[0].message.should.equal 'A missing a documentation block comment'

    it 'should catch a missing *', ->
      errors = lintText """
        ###
        # @class A
        ###
        class A
          ###*
          # @property prop
          ###
          prop: 'a'
      """
      errors.should.have.lengthOf 1
      errors[0].message.should.equal 'Docs for A missing starting * character'

    it 'should catch a missing @class', ->
      errors = lintText """
        ###*
        # This is a test class
        ###
        class A
          ###*
          # @property prop
          ###
          prop: 'a'
      """
      errors.should.have.lengthOf 1
      errors[0].message.should.equal 'Docs for A missing markup'

  context 'property', ->
    it 'should catch a missing docstring', ->
      errors = lintText """
        ###*
        # @class A
        ###
        class A
          prop: 'a'
      """
      errors.should.have.lengthOf 1
      errors[0].message.should.equal 'prop missing a documentation block comment'

    it 'should catch a missing *', ->
      errors = lintText """
        ###*
        # @class A
        ###
        class A
          ###
          # @property prop
          ###
          prop: 'a'
      """
      errors.should.have.lengthOf 1
      errors[0].message.should.equal 'Docs for prop missing starting * character'

    it 'should catch a missing @property', ->
      errors = lintText """
        ###*
        # @class A
        ###
        class A
          ###*
          # This is a test property
          ###
          prop: 'a'
      """
      errors.should.have.lengthOf 1
      errors[0].message.should.equal 'Docs for prop missing markup'

  context 'method', ->
    it 'should catch a missing docstring', ->
      errors = lintText """
        ###*
        # @class A
        ###
        class A
          meth: ->
            return
      """
      errors.should.have.lengthOf 1
      errors[0].message.should.equal 'meth missing a documentation block comment'

    it 'should catch a missing *', ->
      errors = lintText """
        ###*
        # @class A
        ###
        class A
          ###
          # @method meth
          ###
          meth: ->
            return
      """
      errors.should.have.lengthOf 1
      errors[0].message.should.equal 'Docs for meth missing starting * character'

    it 'should catch a missing @property', ->
      errors = lintText """
        ###*
        # @class A
        ###
        class A
          ###*
          # This is a test method
          ###
          meth: ->
            return
      """
      errors.should.have.lengthOf 1
      errors[0].message.should.equal 'Docs for meth missing markup'

  context 'ember', ->
    it 'should pass a valid ember class', ->
      errors = lintText """
        ###*
        # @class A
        ###
        A = Ember.Object.extend
          ###*
          # @property prop
          ###
          prop: 'A'

          ###*
          # @property prop2
          ###
          prop2: Ember.computed 'prop', ->
            return @get 'prop'

          ###*
          # @method meth
          ###
          meth: ->
            return
      """
      errors.should.have.lengthOf 0

    it 'should catch a missing class docstring', ->
      errors = lintText """
        A = Ember.Object.extend
          ###*
          # @property prop
          ###
          prop: 'A'
      """
      errors.should.have.lengthOf 1
      errors[0].message.should.equal 'A missing a documentation block comment'


    it 'should catch a missing property docstring', ->
      errors = lintText """
        ###*
        # @class A
        ###
        A = Ember.Object.extend
          prop: 'A'
      """
      errors.should.have.lengthOf 1
      errors[0].message.should.equal 'prop missing a documentation block comment'


    it 'should catch a missing computed property docstring', ->
      errors = lintText """
        ###*
        # @class A
        ###
        A = Ember.Object.extend
          prop: Ember.computed 'prop2', ->
            return 'b'
      """
      errors.should.have.lengthOf 1
      errors[0].message.should.equal 'prop missing a documentation block comment'


    it 'should catch a missing method docstring', ->
      errors = lintText """
        ###*
        # @class A
        ###
        A = Ember.Object.extend
          meth: ->
            return
      """
      errors.should.have.lengthOf 1
      errors[0].message.should.equal 'meth missing a documentation block comment'

  context 'nested', ->
    it 'should pass inline functions in classes', ->
      errors = lintText """
        ###*
        # @class A
        ###
        class A
          ###*
          # @property prop
          ###
          prop: 'a'

          ###*
          # @method meth
          ###
          meth: ->
            {
              prop: 'a'
              meth: -> return
            }
            return
      """
      errors.should.have.lengthOf 0

    it 'should pass inline functions in ember classes', ->
      errors = lintText """
        ###*
        # @class A
        ###
        A = Ember.Object.extend
          ###*
          # @property prop
          ###
          prop: Ember.computed 'prop2', ->
            callback = -> return 2
            callback()

          ###*
          # @method meth
          ###
          meth: ->
            {
              prop: 'a'
              meth: -> return
            }
            return
      """
      errors.should.have.lengthOf 0
