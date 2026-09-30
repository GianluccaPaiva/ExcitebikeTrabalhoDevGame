shader_type canvas_item;

// Cores originais a serem substituídas (por padrão, os tons Teal e Ciano de Racer_2)
uniform vec4 target_color_1 : source_color = vec4(0.0, 0.5137, 0.5451, 1.0);  // Sombra / Detalhe escuro (Teal)
uniform vec4 target_color_2 : source_color = vec4(0.6706, 0.9059, 1.0, 1.0);  // Cor principal / Brilho (Ciano)

// Novas cores de substituição (customizáveis livremente no Inspetor)
uniform vec4 new_color_1 : source_color = vec4(0.92, 0.65, 0.05, 1.0);       // Nova cor de sombra (Amarelo Ouro)
uniform vec4 new_color_2 : source_color = vec4(1.0, 0.90, 0.20, 1.0);        // Nova cor principal (Amarelo Vibrante)

uniform float tolerance : hint_range(0.0, 0.5) = 0.15;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	
	if (col.a > 0.01) {
		float dist1 = distance(col.rgb, target_color_1.rgb);
		float dist2 = distance(col.rgb, target_color_2.rgb);
		
		if (dist1 < tolerance) {
			COLOR = vec4(new_color_1.rgb, col.a);
		} else if (dist2 < tolerance) {
			COLOR = vec4(new_color_2.rgb, col.a);
		} else {
			COLOR = col;
		}
	} else {
		COLOR = col;
	}
}
