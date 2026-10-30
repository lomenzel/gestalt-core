Modules "own" a slice of the state. its allways
state._gestaltInternal.<module-name>

modules are app level and not view level because that way they can if not enabled be excluded from view evalmodules to keep runtime snappy

options of a module should all live under 
<cool name to name them. services maybe but that sounds like nixos services>.<module-name> they should all have an enable option which if they have a view module attached to them should then be included

no other module should ever read a modules state slice.
modules have to expose the state they want to be exposed through options or slector function or so

modules (their view part) can expose ui components
for example a settings module might expose the user settings, an option to declare what are fields in settings and how tehy validate, and also a ui component that displays a settings page. or other example a key store module might expose options to set keystore.type = encrypted or plain or even have multiple keystores (which on change reset the state to initial state) and expose a ui component: cfg.keystore.UI.Guard <other component> that wraps the component in an if else so only if a keystore is present and if applicable decrypted the component can be shown. otherwise it replaces it with an enter passphrase or slect keystore type ui. it also might expose Change keystore effects or something similar