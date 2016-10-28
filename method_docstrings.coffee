
class SearchableAstNode
  constructor: (@node, @parent, @index) ->
    @name = @node?.constructor?.name
    if @parent?
      @path = "#{@parent.path}.#{@name}"
    else
      @path = @name

    @children = []
    @node.eachChild (child) =>
      @children.push new SearchableAstNode(child, @, @children.length)

  getChild: (i) ->
    if i >= 0 and i < @children.length
      return @children[i]
    else
      return null

  prevSibling: ->
    @parent.getChild(@index - 1)

  nextSibling: ->
    @parent.getChild(@index + 1)

  search: (pattern) ->
    results = []
    if @path.match(pattern)?
      results.push @

    for child in @children
      results = results.concat child.search(pattern)
    return results

# Method: Class.Block.Value.Obj.Assign.(Value.Literal, Code.Block)
# Property: Class.Block.Value.Obj.Assign.(Value.Literal, Value)

module.exports = class MissingDocumentation
  rule:
    name: 'method_docstrings'
    level: 'warn'
    message: 'Method needs documentation'
    value: 0
    ignore_private: false
    types: ['class', 'method', 'property']
    description: '''
      Examine the complexity of your function.
      '''

  lintAST: (node, @astApi) ->
    @lintNode node
    undefined

  lintDocumentedElement: (element, comment, name) ->
    privateElement = if name[0] is '_' then true else false

    if privateElement and @astApi.config[@rule.name].ignore_private
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

  # Lint the AST node and return its cyclomatic complexity.
  lintNode: (node, prevChild, depth = 0) ->
    # Get the complexity of the current node.
    searchable_node = new SearchableAstNode(node)
    assignments = searchable_node.search /Class.Block.Value.Obj.Assign$/
    klasses = searchable_node.search(/Class$/)

    methods = []
    properties = []
    for assignment in assignments
      continue unless assignment.children[0]?.name is 'Value'
      continue unless assignment.children[0]?.children[0]?.name is 'Literal'

      if assignment.children[1]?.name is 'Code'
        methods.push assignment

      if assignment.children[1]?.name is 'Value'
        properties.push assignment

    unless 'method' in @astApi.config[@rule.name].types
      methods = []

    unless 'property' in @astApi.config[@rule.name].types
      properties = []

    unless 'class' in @astApi.config[@rule.name].types
      klasses = []

    errors = []
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

    for klass in klasses
      name = klass.node.variable?.base?.value
      comment = klass.prevSibling()
      error = @lintDocumentedElement(klass, comment, name)
      errors.push error if error?


    for error in errors
      {message, node} = error
      @errors.push @astApi.createError
        message: message
        lineNumber: node.locationData.first_line + 1
        lineNumberEnd: node.locationData.last_line + 1
