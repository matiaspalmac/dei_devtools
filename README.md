# dei_devtools

Herramientas de desarrollo in-game para FiveM. Parte del ecosistema **Dei**.

## Caracteristicas

- **Resource Monitor (Resmon)** - Lista de recursos con tiempos de ejecucion
- **Event Logger** - Log en tiempo real de eventos client/server
- **Entity Inspector** - Conteo e inspeccion de entidades del mundo
- **Player Inspector** - Datos del jugador, coordenadas, vehiculo, job
- **Network Monitor** - Ping, eventos/segundo, grafico en tiempo real
- **NUI Inspector** - Log de mensajes NUI entre recursos
- **Command Console** - Ejecutar comandos y codigo Lua en tiempo real

## Instalacion

1. Copiar `dei_devtools` a tu carpeta `resources/`
2. Agregar `ensure dei_devtools` a tu `server.cfg`
3. Configurar permisos ACE:

```cfg
add_ace group.admin dei.devtools allow
add_ace group.superadmin dei.devtools.console allow
```

## Configuracion

Editar `config.lua` para ajustar:
- Framework (esx/qbcore/standalone)
- Tecla de apertura (default: F9)
- Tasa de refresco
- Rango de entidades
- Grupos permitidos

## Controles

- **F9** - Abrir/cerrar panel
- **R** - Raycast inspect (mientras el panel esta abierto)
- **Escape** - Cerrar panel

## Permisos

- `dei.devtools` - Acceso general al panel
- `dei.devtools.console` - Acceso a la consola (solo superadmin)

## Temas

Soporta 4 temas del ecosistema Dei: Dark, Midnight, Neon, Minimal + Light Mode.
Se sincroniza automaticamente con otros recursos Dei via KVP y evento `dei:themeChanged`.

---

**Dei** - Ecosistema de recursos para FiveM
