; extends
((storage_class_specifier) @keyword.modifier (#set! priority 110))
((type_qualifier) @keyword.modifier (#set! priority 110))
((enumerator name: (identifier) @constant.builtin.cpp) (#set! priority 110))
((parameter_declaration (reference_declarator "&" @operator.reference)) (#set! priority 110))
((parameter_declaration (reference_declarator "&&" @operator.reference)) (#set! priority 110))
((new_expression "new" @keyword.new) (#set! priority 110))
((delete_expression "delete" @keyword.new) (#set! priority 110))
((init_declarator declarator: (identifier) @function.lambda value: (lambda_expression)) (#set! priority 130))
((delete_expression "[" @keyword.delete.bracket) (#set! priority 130))
((delete_expression "]" @keyword.delete.bracket) (#set! priority 130))
; catch-clause reference operator → distinct capture for white coloring
((catch_clause
  parameters: (parameter_list
    (parameter_declaration
      declarator: (reference_declarator "&" @operator.reference.catch)))) (#set! priority 120))
; C++ cast keywords used as template functions → blue, not yellow function-call color
((call_expression
  function: (template_function
    name: (identifier) @keyword.operator.cast))
 (#any-of? @keyword.operator.cast "static_cast" "dynamic_cast" "const_cast" "reinterpret_cast")
 (#set! priority 120))
 