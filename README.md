# Bimbo Run

Bimbo Run es un copiloto de ruta para vendedores Bimbo construido con SwiftUI.

## MVP actual

- Tabs principales: Camion, Ruta, Tiendas e Impacto.
- Inventario mock del camion.
- Tiendas mock con historial.
- Flujo de escaneo dentro de tienda.
- Recomendacion IA integrada mediante servicio Groq con fallback mock.
- Pedido editable con descuento de inventario.
- Impacto actualizado al confirmar pedidos.

## Configuracion Groq

No subas la API key al repositorio. Crea localmente `GroqConfig.xcconfig` con:

```text
GROQ_API_KEY = tu_api_key
```

Despues enlaza ese xcconfig en Xcode y expone `GROQ_API_KEY` en `Info.plist` como `$(GROQ_API_KEY)`.
