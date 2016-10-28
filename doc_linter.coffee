###*
# @class SearchableAstNode
###
class SearchableAstNode
  ###*
  # @method constructor
  # @param @node CoffeeScript AST Node
  # @param @parent {SearchableAstNode}
  # @param @index {Number} Index in parent
  ###
  constructor: (@node, @parent, @index) ->
    ###*
    # @property name {String} The CoffeeScript AST node type
    ###
    @name = @node?.constructor?.name
    if @parent?
      ###*
      # The chain of names from the root to this node, for example:
      # Block.Class.Block.Value.Obj.Assign.Value.Literal
      # @property path {String}
      ###
      @path = "#{@parent.path}.#{@name}"
    else
      @path = @name

    ###*
    # @property children {SearchableAstNode[]}
    ###
    @children = []
    @node.eachChild (child) =>
      @children.push new SearchableAstNode(child, @, @children.length)

  ###*
  # @method getChild
  # @param i {Number}
  # @return {SearchableAstNode}
  ###
  getChild: (i) ->
    if i >= 0 and i < @children.length
      return @children[i]
    else
      return null

  ###*
  # @method prevSibling
  # @return {SearchableAstNode|null}
  ###
  prevSibling: ->
    @parent.getChild(@index - 1)

  ###*
  # @method nextSibling
  # @return {SearchableAstNode|null}
  ###
  nextSibling: ->
    @parent.getChild(@index + 1)

  ###*
  # @method search
  # @param pattern {RegExp} A pattern for matching `@path`
  # @return {SearchableAstNode[]}
  ###
  search: (pattern) ->
    results = []
    if @path.match(pattern)?
      results.push @

    for child in @children
      results = results.concat child.search(pattern)
    return results

# Method: Class.Block.Value.Obj.Assign.(Value.Literal, Code.Block)
# Property: Class.Block.Value.Obj.Assign.(Value.Literal, Value)

###*
# @class DocLinter
###
module.exports = class DocLinter
  ###*
  # @property rule {Object} The default config
  ###
  rule:
    name: 'require_jsdoc'
    level: 'warn'
    message: 'Method needs documentation'
    value: 0
    ignore_private: false
    types: ['class', 'method', 'property']
    description: '''
      Examine the complexity of your function.
      '''

  ###*
  # @method lintAST
  # @param node CoffeeScript AST Node
  # @param @astApi
  ###
  lintAST: (node, @astApi) ->
    searchable_node = new SearchableAstNode(node)

    # Search for methods/properties, and classes
    assignments = searchable_node.search /Class.Block.Value.Obj.Assign$/
    klasses = searchable_node.search(/Class$/)

    # Filter assignments into methods and properties
    methods = []
    properties = []
    for assignment in assignments
      continue unless assignment.children[0]?.name is 'Value'
      continue unless assignment.children[0]?.children[0]?.name is 'Literal'

      if assignment.children[1]?.name is 'Code'
        methods.push assignment

      if assignment.children[1]?.name is 'Value'
        properties.push assignment

    # Follow config.types setting
    unless 'method' in @astApi.config[@rule.name].types
      methods = []

    unless 'property' in @astApi.config[@rule.name].types
      properties = []

    unless 'class' in @astApi.config[@rule.name].types
      klasses = []

    # Generate errors for each kind of object.
    errors = []
    for klass in klasses
      name = klass.node.variable?.base?.value
      comment = klass.prevSibling()
      error = @lintDocumentedElement(klass, comment, name)
      errors.push error if error?

    for method in methods
      name = method.children[0]?.children[0]?.node.value
      comment = method.prevSibling()
      error = @lintDocumentedElement(method, comment, name)
      errors.push error if error?

    for property in properties
      name = property.children[0]?.children[0]?.node.value
      comment = property.prevSibling()
      error = @lintDocumentedElement(property, comment, name)
      errors.push error if error?

    # Send the errors to the api.
    for error in errors
      {message, node} = error
      @errors.push @astApi.createError
        message: message
        lineNumber: node.locationData.first_line + 1
        lineNumberEnd: node.locationData.last_line + 1

    return

  ###*
  # Make sure the element has formatted documentation.
  #
  # @method lintDocumentedElement
  # @param element {SearchableAstNode}
  # @param comment {SearchableAstNode}
  # @param name {String}
  # @return {Object} An object with `message` and `node`, or null
  ###
  lintDocumentedElement: (element, comment, name) ->
    # Ignore private elements according to settings
    if name[0] is '_' and @astApi.config[@rule.name].ignore_private
      return null

    if not comment? or comment.name isnt 'Comment'
      return {
        message: "#{name} is undocumented"
        node: element.node
      }

    unless comment.node.comment[0] is '*'
      return {
        message: "Docs for #{name} missing starting * character"
        node: comment.node
      }

    unless comment.node.comment.indexOf('@') >= 0
      return {
        "message": "Docs for #{name} missing markup"
        node: comment.node
      }
