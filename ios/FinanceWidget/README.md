# Widget de iOS

El código está listo (`FinanceWidget.swift`), pero el target de la extensión
se crea en Xcode (no se puede generar sin macOS):

1. Abre `ios/Runner.xcworkspace` en Xcode.
2. **File → New → Target… → Widget Extension**. Nombre: `FinanceWidget`;
   desmarca *Include Live Activity* y *Include Configuration App Intent*.
   Si pregunta por activar el scheme, acepta.
3. Borra el `.swift` que Xcode generó dentro de `FinanceWidget/` y añade al
   target el `FinanceWidget.swift` de esta carpeta.
4. En **Signing & Capabilities**, añade **App Groups** a *Runner* y a
   *FinanceWidgetExtension* con el grupo `group.com.example.appgastos`
   (el mismo que `PhoneWidgetService.appGroupId`).
5. Pon el *Deployment Target* de la extensión en iOS 14 o más.

La app guarda los datos y recarga el widget sola con el paquete
`home_widget` cada vez que cambian (balance, contenido o color elegidos en
**Inicio → Personalizar inicio → Widget del teléfono**).
