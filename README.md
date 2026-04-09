# 🚀 Task AI Local (Qwen 2.5)

Una innovadora aplicación de productividad (SaaS-like) para **Android** construida en **Flutter**, diseñada con un enfoque corporativo de priorización y gestión de tareas impulsada 100% por Inteligencia Artificial **Offline**.

Este proyecto no depende de APIs externas (como OpenAI o Anthropic) para su procesamiento semántico. Todo el razonamiento, extracción de fechas y estructuración JSON se ejecuta **localmente en tu dispositivo** mediante un modelo de lenguaje cuantizado **Qwen 2.5 (1.5B)** empoderado por [MediaPipe LiteRT](https://github.com/google/mediapipe).

---

## ✨ Características Principales

### 🧠 Cerebro Local Avanzado (Qwen 2.5 1.5B Instruct)
- **Privacidad Absoluta:** Las tareas personales y empresariales nunca abandonan o se suben a la nube.
- **Modo Offline:** La inteligencia artificial razona las tareas aunque estés sin conexión a internet.
- **Razonamiento Estricto Estructurado:** Obliga a Qwen a deducir lógicamente el proceso y generar **3 sub-tareas creativas** por cada instrucción hablada, forzando títulos ultra-cortos, extracción dinámica de horas y exclusividad del idioma español en todas sus categorías.

### 📡 Autoensamblaje y Red Segura (Dio)
- **Autodescarga In-App:** La aplicación detecta si el modelo neuronal de la IA (1.6 Gigabytes) no existe en los archivos del celular. De ser así, se despliega una interfaz futurista que descarga e instala el "cerebro" directamente de los servidores de *Hugging Face* en tiempo real, sin pedir al usuario que interactúe usando engorrosos comandos `adb`.

### 🎙️ Reconocimiento Continuo de Voz (Bypass Biológico)
- **Dictado Ininterrumpido:** Implementación avanzada de `speech_to_text`. Brinca las agresivas suspensiones forzosas de micrófono integradas para ahorro de batería por OEMs en Androids (Xiaomi, Samsung) gracias a la bandera nativa oculta de _Dictation Mode_ continua.
- **Caché Híbrida de Contexto:** El usuario puede teclear, quedarse en un profundo silencio para pensar y volver a hablar. La App unifica dinámicamente todo lo detectado en la caja de edición sin sobrescribir o vaciar datos valiosos del dictado anterior.

### 🎨 Arquitectura Lógica de UI (UX "Nivel SaaS")
- **Gestos Deslizables Bi-Direccionales (`Dismissible`):**
  - **Swipe Izquierdo ⬅️:** Eliminación rápida (Papelera roja). Interceptado por escudos de Pop-ups Dialog (Anti-Borrados por Error).
  - **Swipe Derecho ➡️:** Edición Mágica. Muestra el modal de corrección y "rebota" instintivamente la tarjeta para que no caiga al archivo de borrados.
- **Notificaciones Flotantes `Snackbars`:** Estéticas tipo Isla Dinámica que flotan en la pantalla con alta durabilidad (8 segundos), colores vibrantes estandarizados de suceso o error, y siempre acompañados de un botón para cierre anticipado manual.
- **Teleprompter y Cajas Expandibles:** Caja de texto con inteligencia métrica `scrollLimit`. Cuenta con 5 pisos de expansión máxima y auto-seguimiento (`offset`) del cursor que viaja matemáticamente hasta la última palabra hablada. Acompañada con un "Pro-Tip" guía flotante para educar al usuario sobre los mejores tipos de "Prompting".

---

## 🛠 Instalación y Despliegue

### Requisitos Previos Generales
1. **Flutter SDK** instalado (Versión > 3.x.x)
2. **Dispositivo Android Moderno** de 64 Bits con **mínimo 4GB - 6GB de RAM**. (Este número es severamente recomendado para poder alojar el contexto temporal de la IA viva en el momento de inferencia sin desencadenar las extinciones del sistema: *Out of Memory Culling*).

### Instrucciones de Ejecución Rapida
1. Clona el repositorio oficial de ParqueSoft:
```bash
git clone https://github.com/ParqueSoft-Crea/Task-IA-Local.git
cd Task-IA-Local
```

2. Descarga la arquitectura de paquetes:
```bash
flutter pub get
```

3. Ejecuta los flujos pesados de la app en tu celular en vivo:
```bash
flutter run
```

> **⚠️ PRECAUCIÓN DE PRIMER INICIO:** Al abrir la App exitosamente por *Primera Única Vez*, se someterá a su iniciación descargando el Cerebro (`Qwen`). Revisa tener al menos 2GB libres de Memoria de Almacenamiento local extra, mantén la pantalla del equipo despierta y cerciórate de haber seleccionado una red WiFi lo suficientemente robusta. ¡Cuando la "Isla Verde Flotante" anuncie su cierre, la App fluirá!

---

## 💡 Guión Táctico (Ejemplo de Rendimiento)
Esta Inteligencia Artificial razona basándose sumamente en Prompts causales. Usa instrucciones organizadas:

**Fórmula Genuina Excelente:**
> *"Organizar la fiesta comercial de ParqueSoft para mañana. Pasos: Primero, llamar al catering a las 10 pm. Luego, adquirir las bebidas gaseosas a las 3 de la tarde. Y organizar a los invitados a las 7 am."*

La red neuronal convertirá el ruido blanco de tu simple dictado a una taxonomía pura para el backend:
Asignando fechas directas en *Timestamp* (`2026-03-24T22:00:00`), identificando y abstrayendo inteligentemente tres actividades jerárquicas exactas, resumiendo tu idea principal a 5 palabras concretas, pero conservando y asegurando tu párrafo intocable para preservar un registro oficial de tu instrucción final.

---

## 📄 Estantería de Licencias
Un proyecto desarrollado con pasión investigativa por y para **ParqueSoft-Crea**.
*   **MediaPipe / LiteRT** — Apache 2.0 (Google LLC)
*   **SpeechToText / Flutter Core** — BSD Licenses
*   **Modelos Qwen 2.5 (Alibaba Cloud)** — Qwen Research Weights Open Source.
