package bindgen

import "core:os"
import "core:fmt"

export_defines :: proc(data : ^GeneratorData) {
    for node in data.nodes.defines {
        defineName := clean_define_name(node.name, data.options);

        // @fixme fprint of float numbers are pretty badly handled,
        // just has a 10^-3 precision. 
        fmt.fprint(data.handle, defineName, " :: ", node.value, ";\n");
    }
    fmt.fprint(data.handle, "\n");
}

export_type_aliases :: proc(data : ^GeneratorData) {
    for node in data.nodes.typeAliases {
        aliasName := clean_pseudo_type_name(node.name, data.options);
        sourceType := clean_type(node.sourceType, data.options);
        fmt.fprint(data.handle, aliasName, " :: ", sourceType, ";\n");
    }
    fmt.fprint(data.handle, "\n");
}

export_function_pointer_type_aliases :: proc(data : ^GeneratorData) {
    for node in data.nodes.functionPointerTypeAliases {
        aliasName := clean_pseudo_type_name(node.name, data.options);
        fmt.fprint(data.handle, aliasName, " :: #type proc(");
        export_function_parameters(data, node.parameters, "");
        fmt.fprint(data.handle, ");\n");
    }
    fmt.fprint(data.handle, "\n");
}

export_enums :: proc(data : ^GeneratorData) {
    for node in data.nodes.enumDefinitions {
        enumName := clean_pseudo_type_name(node.name, data.options);
        fmt.fprint(data.handle, enumName, " :: enum i32 {");

        postfixes : [dynamic]string;
        enumName, postfixes = clean_enum_name_for_prefix_removal(enumName, data.options);

        // Changing the case of postfixes to the enum value one,
        // so that they can be removed. 
        enumValueCase := find_case(node.members[0].name);
        for postfix, i in postfixes {
            postfixes[i] = change_case(postfix, enumValueCase);
        }

        // Merging enum value postfixes with postfixes that have been removed from the enum name.
        for postfix in data.options.enumValuePostfixes {
            append(&postfixes, postfix);
        }

        export_enum_members(data, node.members, enumName, postfixes[:]);
        fmt.fprint(data.handle, "};\n");
        fmt.fprint(data.handle, "\n");
    }
}

export_structs :: proc(data : ^GeneratorData) {
    for node in data.nodes.structDefinitions {
        structName := clean_pseudo_type_name(node.name, data.options);
        fmt.fprint(data.handle, structName, " :: struct #packed {");
        export_struct_or_union_members(data, node.members);
        fmt.fprint(data.handle, "};\n");
        fmt.fprint(data.handle, "\n");
    }
}

export_unions :: proc(data : ^GeneratorData) {
    for node in data.nodes.unionDefinitions {
        unionName := clean_pseudo_type_name(node.name, data.options);
        fmt.fprint(data.handle, unionName, " :: struct #raw_union {");
        export_struct_or_union_members(data, node.members);
        fmt.fprint(data.handle, "};\n");
        fmt.fprint(data.handle, "\n");
    }
}

export_functions :: proc(data : ^GeneratorData) {
    for node in data.nodes.functionDeclarations {
        functionName := clean_function_name(node.name, data.options);
        fmt.fprint(data.handle, "    @(link_name=\"", node.name, "\")\n");
        fmt.fprint(data.handle, "    ", functionName, " :: proc(");
        export_function_parameters(data, node.parameters, "    ");
        fmt.fprint(data.handle, ")");
        returnType := clean_type(node.returnType, data.options);
        if len(returnType) > 0 {
            fmt.fprint(data.handle, " -> ", returnType);
        }
        fmt.fprint(data.handle, " ---;\n");
        fmt.fprint(data.handle, "\n");
    }
}


export_enum_members :: proc(data : ^GeneratorData, members : [dynamic]EnumMember, enumName : string, postfixes : []string) {
    if (len(members) > 0) {
        fmt.fprint(data.handle, "\n");
    }
    for member in members {
        name := clean_enum_value_name(member.name, enumName, postfixes, data.options);
        if len(name) == 0 do continue;
        fmt.fprint(data.handle, "    ", name);
        if member.hasValue {
            fmt.fprint(data.handle, " = ", member.value);
        }
        fmt.fprint(data.handle, ",\n");
    }
}

export_struct_or_union_members :: proc(data : ^GeneratorData, members : [dynamic]StructOrUnionMember) {
    if (len(members) > 0) {
        fmt.fprint(data.handle, "\n");
    }
    for member in members {
        kind := clean_type(member.kind, data.options);
        name := clean_variable_name(member.name, data.options);
        fmt.fprint(data.handle, "    ", name, " : ");
        if member.dimension > 0 {
            fmt.fprint(data.handle, "[", member.dimension, "]");
        }
        fmt.fprint(data.handle, kind, ",\n");
    }
}

export_function_parameters :: proc(data : ^GeneratorData, parameters : [dynamic]FunctionParameter, baseTab : string) {
    // Special case: function(void) does not really have a parameter
    if (len(parameters) == 1) &&
       (parameters[0].kind.main == "void") &&
       (parameters[0].kind.prefix == "" && parameters[0].kind.postfix == "") {
        return;
    }

    tab := "";
    if (len(parameters) > 1) {
        fmt.fprint(data.handle, "\n");
        tab = fmt.tprint(baseTab, "    ");
    }

    for parameter, i in parameters {
        kind := clean_type(parameter.kind, data.options);
        name := len(parameter.name) != 0 ? clean_variable_name(parameter.name, data.options) : "---";
        fmt.fprint(data.handle, tab, name, " : ");
        if parameter.dimension > 0 {
            fmt.fprint(data.handle, "[", parameter.dimension, "]");
        }
        fmt.fprint(data.handle, kind);
        if i != len(parameters) - 1 {
            fmt.fprint(data.handle, ",\n");
        }
    }

    if (len(parameters) > 1) {
        fmt.fprint(data.handle, "\n", baseTab);
    }
}
