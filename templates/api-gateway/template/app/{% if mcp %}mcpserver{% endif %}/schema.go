package mcpserver

import (
	"google.golang.org/protobuf/reflect/protoreflect"
)

// maxDepth corta mensajes recursivos (un árbol de comentarios, por ejemplo):
// más abajo el campo queda como objeto libre y lo valida el servicio.
const maxDepth = 5

// inputSchema arma el JSON Schema de entrada de una herramienta a partir del
// mensaje de request del RPC. Los nombres son los del .proto (snake_case),
// que es como los aceptan el path, la query y el body de grpc-gateway.
func inputSchema(md protoreflect.MessageDescriptor, required []string) map[string]any {
	s := messageSchema(md, 0)
	if len(required) > 0 {
		s["required"] = required
	}
	return s
}

func messageSchema(md protoreflect.MessageDescriptor, depth int) map[string]any {
	props := map[string]any{}
	fields := md.Fields()
	for i := range fields.Len() {
		f := fields.Get(i)
		props[string(f.Name())] = fieldSchema(f, depth)
	}
	return map[string]any{"type": "object", "properties": props, "additionalProperties": false}
}

func fieldSchema(f protoreflect.FieldDescriptor, depth int) map[string]any {
	if f.IsMap() {
		return map[string]any{"type": "object", "additionalProperties": kindSchema(f.MapValue(), depth)}
	}
	s := kindSchema(f, depth)
	if f.IsList() {
		return map[string]any{"type": "array", "items": s}
	}
	return s
}

func kindSchema(f protoreflect.FieldDescriptor, depth int) map[string]any {
	switch f.Kind() {
	case protoreflect.BoolKind:
		return map[string]any{"type": "boolean"}
	case protoreflect.Int32Kind, protoreflect.Sint32Kind, protoreflect.Sfixed32Kind,
		protoreflect.Uint32Kind, protoreflect.Fixed32Kind:
		return map[string]any{"type": "integer"}
	case protoreflect.Int64Kind, protoreflect.Sint64Kind, protoreflect.Sfixed64Kind,
		protoreflect.Uint64Kind, protoreflect.Fixed64Kind:
		// protojson acepta número o string; responde string.
		return map[string]any{"type": []string{"integer", "string"}}
	case protoreflect.FloatKind, protoreflect.DoubleKind:
		return map[string]any{"type": "number"}
	case protoreflect.StringKind:
		return map[string]any{"type": "string"}
	case protoreflect.BytesKind:
		return map[string]any{"type": "string", "contentEncoding": "base64"}
	case protoreflect.EnumKind:
		vals := f.Enum().Values()
		names := make([]string, 0, vals.Len())
		for i := range vals.Len() {
			names = append(names, string(vals.Get(i).Name()))
		}
		return map[string]any{"type": "string", "enum": names}
	case protoreflect.MessageKind, protoreflect.GroupKind:
		return messageKindSchema(f.Message(), depth)
	}
	return map[string]any{}
}

// messageKindSchema: los tipos conocidos de google.protobuf tienen su forma
// JSON propia (protojson); el resto es un objeto con sus campos.
func messageKindSchema(md protoreflect.MessageDescriptor, depth int) map[string]any {
	switch md.FullName() {
	case "google.protobuf.Timestamp":
		return map[string]any{"type": "string", "format": "date-time"}
	case "google.protobuf.Duration":
		return map[string]any{"type": "string", "description": "duración, ej. 1.5s"}
	case "google.protobuf.FieldMask":
		return map[string]any{"type": "string", "description": "campos separados por coma"}
	case "google.protobuf.Struct":
		return map[string]any{"type": "object"}
	case "google.protobuf.Value":
		return map[string]any{}
	case "google.protobuf.ListValue":
		return map[string]any{"type": "array"}
	case "google.protobuf.StringValue", "google.protobuf.BytesValue":
		return map[string]any{"type": "string"}
	case "google.protobuf.BoolValue":
		return map[string]any{"type": "boolean"}
	case "google.protobuf.Int32Value", "google.protobuf.UInt32Value":
		return map[string]any{"type": "integer"}
	case "google.protobuf.Int64Value", "google.protobuf.UInt64Value":
		return map[string]any{"type": []string{"integer", "string"}}
	case "google.protobuf.FloatValue", "google.protobuf.DoubleValue":
		return map[string]any{"type": "number"}
	}
	if depth >= maxDepth {
		return map[string]any{"type": "object"}
	}
	return messageSchema(md, depth+1)
}
