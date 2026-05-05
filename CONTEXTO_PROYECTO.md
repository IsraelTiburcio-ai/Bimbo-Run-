# Bimbo Run - Contexto del Proyecto

## Vision

Bimbo Run es un copiloto de ruta para vendedores Bimbo. La app busca ayudar al vendedor a trabajar mas rapido en campo: saber que tienda sigue, que inventario trae en el camion, que productos debe revisar, que debe retirar, que debe reponer y como impacta su jornada.

La IA no reemplaza la experiencia del vendedor. La complementa. El vendedor sigue tomando la decision final, pero la app reduce la carga manual y le da contexto cuando esta en ruta, frente al anaquel o atendiendo una tienda.

## Problema

Un vendedor de ruta puede tardar entre 30 y 45 minutos por visita. Parte del tiempo se pierde en revisar producto uno por uno, validar caducidades, contar inventario, recordar pedidos anteriores, preguntar que se vendio y decidir cuanto dejar.

La oportunidad de Bimbo Run es reducir esa revision manual. Aunque la IA no acierte todo al 100% desde el primer dia, puede priorizar los productos mas importantes. En vez de revisar 10 productos manualmente, el vendedor podria revisar 2 o 3 productos marcados como prioritarios.

Esto ayuda a:

- Ahorrar tiempo por tienda.
- Evitar producto caducado en anaquel.
- Reducir merma.
- Mejorar surtido por tipo de tienda.
- Apoyar a vendedores nuevos.
- Disminuir cansancio visual y fisico en campo.
- Mejorar datos para ventas, logistica y operaciones.

## Producto Actual Implementado

El MVP actual ya existe en SwiftUI como una app navegable llamada **Bimbo Run**.

Stack actual:

- SwiftUI.
- iOS 17+.
- Observation con `@Observable`.
- `NavigationStack`.
- `TabView`.
- Datos mock locales en memoria.
- Sin dependencias externas.
- Sin IA real, mapas reales, OCR real, login, pagos ni facturacion.

La app abre en `MainTabView` y selecciona inicialmente el tab **Ruta**, porque Ruta es el copiloto principal del dia.

Tabs actuales:

1. **Camion**
2. **Ruta**
3. **Tiendas**
4. **Impacto**

El escaneo no es tab principal. Vive dentro del flujo de tienda.

Flujos funcionales actuales:

- `Ruta -> Entrar a tienda -> Escanear anaquel -> Recomendacion IA -> Confirmar pedido`.
- `Tiendas -> Detalle de tienda -> Escanear anaquel -> Recomendacion IA -> Confirmar pedido`.
- `Tiendas -> Agregar tienda`.
- `Camion -> Escanear ticket de carga` como accion mock.
- `Impacto` muestra metricas actualizadas despues de confirmar pedidos.

## Arquitectura Actual

El estado principal vive en `RoutePerfectaViewModel`.

Estado central:

- `stores`: tiendas mock.
- `routeStops`: paradas de ruta mock.
- `truckInventory`: inventario mock del camion.
- `savedMinutes`: tiempo ahorrado mock.
- `avoidedWaste`: merma evitada mock.
- `estimatedSales`: ventas estimadas mock.
- `removedProductsCount`: producto retirado a tiempo.

Metodos clave:

- `mockScanResult(storeId:)`: genera recomendacion IA mock.
- `confirmOrder(storeId:items:notes:)`: confirma pedido, descuenta inventario, marca tienda como completada y actualiza metricas.
- `addStore(...)`: agrega tienda pendiente de validar.
- `startVisit(storeId:)`: marca tienda/parada en progreso.
- `store(for:)`: recupera tienda.
- `nextPendingStop`: calcula siguiente parada pendiente.

Modelos actuales:

- `Product`.
- `TruckInventoryItem`.
- `Store`.
- `RouteStop`.
- `OrderItem`.
- `ScanResult`.

Componentes actuales:

- `KPIStatCard`.
- `InventoryMiniCard`.
- `StoreRouteCard`.
- `PrimaryButton`.
- `StatusBadge`.
- `StoreCard`.

## Tabs y Responsabilidad

### Camion

El tab **Camion** muestra el inventario actual del camion.

Hoy muestra:

- Productos disponibles.
- Productos reservados o sugeridos.
- Productos retirados/devoluciones.
- Alertas de bajo inventario.
- Boton mock `Escanear ticket de carga`.
- Resumen de inventario restante para tiendas pendientes.

Intencion del modulo:

- Que el vendedor sepa que trae antes y durante la ruta.
- Que el sistema pueda descontar producto conforme confirma pedidos.
- Que en el futuro pueda cargar inventario desde foto/OCR de hoja o ticket.
- Que el vendedor pueda consultar inventario por voz sin distraerse.

### Ruta

El tab **Ruta** es el centro del producto.

Hoy muestra:

- Mapa mock o card visual de ruta.
- Progreso del dia.
- Siguiente tienda.
- Boton `Entrar a tienda`.
- Boton mock `Abrir en Maps/Waze`.
- Inventario resumido.
- Lista de paradas.

Intencion del modulo:

- Guiar al vendedor desde deposito a tiendas y de regreso.
- Priorizar por tiempo, no solo por cercania.
- En el futuro considerar trafico, horas pico, bloqueos y ventanas de atencion.
- Integrarse con Google Maps, Waze o Apple Maps para navegacion real.

### Tiendas

El tab **Tiendas** permite consultar y administrar tiendas.

Hoy muestra:

- Lista de tiendas mock.
- Buscador.
- Boton `Agregar tienda`.
- Detalle de tienda con historial.
- Productos mas vendidos.
- Productos de baja rotacion.
- Ultimos productos dejados.
- Presupuesto estimado.
- Boton `Escanear anaquel`.

Intencion del modulo:

- Dar contexto antes de vender.
- Apoyar a vendedores nuevos.
- Recordar historial cuando no esta el tendero habitual.
- Ser la base para recomendaciones futuras por tienda.

### Impacto

El tab **Impacto** reemplaza el concepto anterior de Analisis.

Hoy muestra:

- Tiempo ahorrado.
- Tiendas completadas.
- Merma evitada.
- Ventas estimadas.
- Producto retirado.
- Inventario restante.
- Logros: Productividad, Merma cero y Ruta eficiente.

Intencion del modulo:

- Mostrar valor directo al vendedor.
- Motivar con progreso y logros.
- En el futuro conectar con comisiones, bonos o metas internas si la empresa lo define.
- Generar datos historicos para estrategia comercial y logistica.

## Flujo de Tienda

El flujo ideal dentro de una tienda es:

1. Entrar desde Ruta o desde Tiendas.
2. Revisar contexto de tienda.
3. Ver historial, productos dejados y presupuesto estimado.
4. Escanear anaquel.
5. Simular lectura de QR/caducidades/historial.
6. Mostrar recomendacion IA mock.
7. Aceptar o ajustar manualmente.
8. Confirmar pedido.
9. Descontar inventario del camion.
10. Registrar productos retirados/devoluciones.
11. Marcar tienda como completada.
12. Actualizar Impacto.
13. Regresar a Ruta.

El escaneo actual es simulado con mensajes:

- `Leyendo QR...`
- `Validando caducidades...`
- `Cruzando historial de pedido...`
- `Calculando recomendacion...`

## Recomendacion IA Mock

La recomendacion actual es mock, pero representa lo que deberia hacer la IA real.

Hoy muestra:

- Productos a retirar.
- Productos a reponer.
- Productos sugeridos segun inventario disponible.
- Alertas si el inventario no alcanza.
- Sugerencias de acomodo.

La IA futura debe considerar:

- Foto o video del anaquel.
- QR o codigos de producto.
- Lote y caducidad.
- Historial de pedidos.
- Productos dejados en visitas anteriores.
- Ventas por tienda.
- Tipo de tienda y ubicacion.
- Temporada.
- Presupuesto del tendero.
- Inventario disponible del camion.
- Opinion del tendero.

## Inventario del Camion

El inventario es una pieza central del producto. No solo es una lista: afecta la recomendacion, el pedido y la ruta.

Hoy el inventario:

- Existe como datos mock en memoria.
- Tiene cantidad disponible.
- Tiene cantidad reservada/sugerida.
- Tiene retirados/devoluciones.
- Tiene alertas de bajo inventario.
- Se descuenta al confirmar pedido.

A futuro debe:

- Cargarse desde foto del ticket u hoja de carga.
- Actualizarse automaticamente con cada pedido.
- Sumar producto retirado o devuelto.
- Alertar si no alcanza para tiendas pendientes.
- Sugerir redistribucion segun ruta.
- Poder consultarse por voz.

Ejemplo futuro por voz:

> Oye, cuanto inventario me queda?

Respuesta esperada:

> Te quedan 12 Pan Blanco, 8 Medias Noches y 20 Takis. Consideralo para las 3 tiendas pendientes.

## Rutas y Mapas

La ruta debe iniciar y terminar en el deposito.

La optimizacion futura no debe depender solo de cercania. Debe priorizar tiempo operativo:

- Distancia.
- Trafico.
- Horas pico.
- Bloqueos.
- Regreso al deposito.
- Ventanas de atencion.
- Inventario restante.
- Tiendas prioritarias.

La app puede mostrar un mapa general tipo vista de ruta, pero la navegacion real deberia abrirse en Google Maps, Waze o Apple Maps.

## Human Centered AI

Bimbo Run debe estar disenada para campo.

Principios:

- La IA acompana, no reemplaza.
- El vendedor siempre puede ajustar.
- La app debe funcionar rapido con una mano.
- Los botones deben ser grandes.
- La UI debe ser clara en exterior y compatible con Dark Mode.
- La voz debe ayudar cuando el vendedor no puede mirar la pantalla.
- El flujo debe reducir cansancio visual y revision manual.

Caso clave:

Si el vendedor llega a una tienda y no esta la persona habitual, Bimbo Run debe darle suficiente contexto para continuar: ultimo pedido, productos dejados, caducidades esperadas, productos mas vendidos y recomendacion sugerida.

## Valor para Usuarios

### Para el vendedor

- Menos tiempo revisando producto.
- Menos esfuerzo contando inventario.
- Mejor contexto por tienda.
- Recomendaciones editables.
- Visibilidad de avance e impacto.
- Mejor oportunidad de cumplir metas.

### Para la tienda

- Mejor surtido segun venta real.
- Menos producto caducado.
- Anaquel mas ordenado.
- Recomendaciones ajustadas al presupuesto.

### Para Bimbo

- Menos merma.
- Mas eficiencia por ruta.
- Mayor capacidad de visitar mas tiendas.
- Mejor control de inventario en campo.
- Datos historicos para ventas, operaciones y logistica.

### Para el consumidor

- Menor riesgo de comprar producto caducado.
- Mejor disponibilidad de producto de alta demanda.
- Anaqueles mejor cuidados.

## Roadmap

### MVP actual

- App SwiftUI navegable.
- Tabs Camion, Ruta, Tiendas e Impacto.
- Datos mock locales.
- Inventario mock funcional.
- Tiendas mock con historial.
- Escaneo simulado dentro de flujo de tienda.
- Recomendacion IA mock.
- Pedido editable.
- Confirmacion de pedido.
- Descuento de inventario.
- Actualizacion de metricas de Impacto.

### Siguiente etapa

- OCR real para ticket de carga.
- Persistencia local o backend.
- Mapas reales.
- Deep link a Google Maps, Waze o Apple Maps.
- Captura real de anaquel con camara.
- Reconocimiento real de producto, lote y caducidad.
- Recomendaciones IA conectadas a datos reales.
- Consulta por voz.
- Modo offline.

### Vision empresarial

- Login por vendedor.
- Rutas asignadas por deposito.
- Data warehouse para historicos.
- Forecast de inventario por ruta.
- Analisis por zona, temporada y tipo de tienda.
- Metas, logros, comisiones o bonos configurables por la empresa.
- Integracion con pagos/facturacion si aplica.

## Pitch Actual

Bimbo Run convierte la jornada del vendedor en una ruta guiada por datos. Desde el camion, el vendedor sabe que inventario trae. En ruta, sabe cual tienda sigue. Dentro de tienda, escanea el anaquel y recibe una recomendacion mock de que retirar, que reponer y que sugerir. Al confirmar pedido, el inventario se actualiza y el impacto de la jornada queda visible.

El valor esta en ahorrar tiempo, reducir merma, cuidar al consumidor y generar datos utiles para que Bimbo mejore ventas, logistica y operaciones.

