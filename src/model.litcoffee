# Model - instance of schema-driven data

The `Model` class is where the [Yang](./yang.litcoffee) schema
expression and the data object come together to provide the *adaptive*
and *event-driven* data interactions.

It is typically not instantiated directly, but is generated as a
result of [Yang::eval](./yang.litcoffee#eval-data-opts).

```javascript
var schema = Yang.parse('container foo { leaf a { type uint8; } }');
var model = schema.eval({ foo: { a: 7 } });
// model is { foo: [Getter/Setter] }
// model.foo is { a: [Getter/Setter] }
// model.foo.a is 7
```

The generated `Model` is a hierarchical composition of
[Property](./property.litcoffee) instances. The instance itself uses
`Object.preventExtensions` to ensure no additional properties that are
not known to itself can be added.

## Class Model

    Stack    = require 'stacktrace-parser'
    Emitter  = require './emitter'
    Property = require './property'

    class Model extends Emitter
      constructor: (props...) ->
        props = ([].concat props...).filter (prop) ->
          prop instanceof Property
        super
        prop.join this for prop in props
        Object.preventExtensions this

## Instance-level methods

### on (event)

The `Model` instance is an `EventEmitter` and you can attach various
event listeners to handle events generated by the `Model`:

event | arguments | description
--- | --- | ---
update | (prop, prev) | fired when an update takes place within the data tree
change | (elems...) | fired when the schema is modified
create | (items...) | fired when one or more `list` element is added
delete | (items...) | fired when one or more `list` element is deleted

It also accepts optional XPATH/YPATH expressions which will *filter*
for granular event subscription to specified events from only the
elements of interest.

The event listeners to the `Model` can handle any customized behavior
such as saving to database, updating read-only state, scheduling
background tasks, etc.

This operation is protected from recursion, where operations by the
`callback` may result in the same `callback` being executed multiple
times due to subsequent events triggered due to changes to the
`Model`. Currently, it will allow the same `callback` to be executed
at most two times.

      on: (event, filters..., callback) ->
        unless callback instanceof Function
          throw new Error "must supply callback function to listen for events"
          
        recursive = (name) ->
          seen = {}
          frames = Stack.parse(new Error().stack)
          for frame, i in frames when ~frame.methodName.indexOf(name)
            { file, lineNumber, column } = frames[i-1]
            callee = "#{file}:#{lineNumber}:#{column}"
            seen[callee] ?= 0
            if ++seen[callee] > 1
              console.warn "detected recursion for '#{callee}'"
              return true 
          return false

        $$$ = (prop, args...) ->
          console.debug? "$$$: check if '#{prop.path}' in '#{filters}'"
          if not filters.length or prop.path.contains filters...
            unless recursive('$$$')
              callback.apply this, [prop].concat args

        super event, $$$

Please refer to [Model Events](../TUTORIAL.md#model-events) section of
the [Getting Started Guide](../TUTORIAL.md) for usage examples.

### in (pattern)

A convenience routine to locate one or more matching Property
instances based on `pattern` (XPATH or YPATH) from this Model.

      in: (pattern) ->
        return unless typeof pattern is 'string'
        return (prop for k, prop of @__props__) if pattern is '/'
        for k, prop of @__props__
          try props = prop.find(pattern).props
          catch then continue
        return unless props?
        return switch
          when not props.length then null
          when props.length > 1 then props
          else props[0]

## Export Model Class

    exports = module.exports = Model
    exports.Property = Property
