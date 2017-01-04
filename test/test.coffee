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
          ###*
          # @property prop
          ###
          prop: 'a'

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

    it 'should catch a missing @method', ->
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

  context 'regression', ->
    for text, i in [
      """
        RansacDefaults = {
          numIterations: 300
        }

        IRLSDefaults = {
          numIterations: 100
        }

        numeric.T.prototype.sum = () ->
          numeric.sum(@x)

        numeric.T.prototype.dim = () ->
          numeric.dim(@x)

        numeric.T.prototype.pow = (p) ->
          numeric.t(numeric.pow(@x, p))

        # Generate m values from [0...n)
        # Only has good performance if n >> m
        randomSampleWithoutReplacement = (m, n) ->
          choices = []
          if (m > n)
            return null
          for i in [0...m]
            guess = Math.floor(Math.random()*n)
            while guess in choices
              guess = Math.floor(Math.random()*n)
            choices.push(guess)
          return choices

        # Check that Ax=b is a valid matrix equation
        wellFormatted = (A, b) ->
          [m, n] = A.dim()
          return (true and
            # A is a matrix
            A.dim().length == 2 and
            # A and b have same length
            m == b.dim()[0] and
            # b is a vector
            b.dim().length == 1 and
            # A has enough rows
            m >= n)

        filterInliers = (A, x, b, thresh) ->
          A.dot(x).sub(b).abs() - 1


        IRLS = (A, b, rho, opts) ->
          {
            numIterations
          } = $.extend({},IRLSDefaults, opts)

          if not wellFormatted(A, b)
            return null

          [m, n] = A.dim()

          x = LeastSquares(A, b)
          resid = A.dot(x).sub(b)

          for i in [1...numIterations]
            Aw = []
            for i in [0...m]
              numeric.mul(A[i], rho(resid[i]))
            x = LeastSquares(Aw, b)
            resid = A.dot(x).sub(b)



        LeastSquares = (A_, b_) ->
          A = numeric.t(A_)
          b = numeric.t(b_)

          # Make sure arrays are well formatted
          if not wellFormatted(A, b)
            return null

          x = (A.transpose().dot(A)).inv().dot(A.transpose()).dot(b)

          return x.x

        LpRansac = (A_, b_, p, opts) ->
          {
            numIterations
          } = $.extend({},RansacDefaults, opts)

          A = numeric.t(A_)
          b = numeric.t(b_)

          [m, n] = A.dim()

          # Make sure arrays are well formatted
          if not wellFormatted(A, b)
            return null

          # Keep a random sample
          Asample = A.getRows(0, n-1)
          bsample = b.getRows(0, n-1)

          # Save best result
          best_norm = Infinity
          best_x = null

          # Try many random solutions
          for iter in [0...numIterations]
            indices = randomSampleWithoutReplacement(n, m)
            # Set rows and columns of matrix
            for i in [0...n]
              Asample.setRow(i, A.getRow(indices[i]))
              bsample.setRow(i, b.getRow(indices[i]))
            # Solve for guess
            x =  numeric.t(numeric.solve(Asample.x, bsample.x))
            # Calculate residuals (Ax - b)
            res = A.dot(x).sub(b)
            # Take Lp Norm
            norm = Math.pow(res.abs().pow(p).sum() / m, 1/p)
            # Save best result
            if norm < best_norm
              best_norm = norm
              best_x = x
          return {x: best_x.x, error: best_norm}

        L1Ransac = (A_, b_, opts) ->
          {
            numIterations
          } = $.extend({},RansacDefaults, opts)

          A = numeric.t(A_)
          b = numeric.t(b_)

          [m, n] = A.dim()

          # Make sure arrays are well formatted
          if not wellFormatted(A, b)
            return null

          # Keep a random sample
          Asample = A.getRows(0, n-1)
          bsample = b.getRows(0, n-1)

          # Save best result
          best_norm = Infinity
          best_x = null

          # Try many random solutions
          for iter in [0...numIterations]
            indices = randomSampleWithoutReplacement(n, m)
            # Set rows and columns of matrix
            for i in [0...n]
              Asample.setRow(i, A.getRow(indices[i]))
              bsample.setRow(i, b.getRow(indices[i]))
            # Solve for guess
            x = Asample.inv().dot(bsample)
            # Calculate residuals (Ax - b)
            res = A.dot(x).sub(b)
            # Take L1 Norm
            norm = res.abs().sum() / m
            # Save best result
            if norm < best_norm
              best_norm = norm
              best_x = x
          return {x: best_x.x, error: best_norm}

        `export {L1Ransac, LpRansac, LeastSquares}`
      """
    ]
      it "should not fail for sample #{i}", ->
        lintText text
