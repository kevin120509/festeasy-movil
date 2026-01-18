-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.bloqueos_calendario (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  proveedor_usuario_id uuid NOT NULL,
  fecha_bloqueada date NOT NULL,
  motivo character varying DEFAULT 'Ocupado'::character varying,
  creado_en timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT bloqueos_calendario_pkey PRIMARY KEY (id)
);
CREATE TABLE public.carrito (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  cliente_usuario_id uuid NOT NULL,
  fecha_servicio_deseada date,
  direccion_servicio character varying,
  latitud_servicio numeric,
  longitud_servicio numeric,
  estado text NOT NULL DEFAULT 'activo'::text CHECK (estado = ANY (ARRAY['activo'::text, 'abandonado'::text, 'convertido'::text])),
  creado_en timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
  actualizado_en timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT carrito_pkey PRIMARY KEY (id),
  CONSTRAINT carrito_cliente_usuario_id_fkey FOREIGN KEY (cliente_usuario_id) REFERENCES public.users(id)
);
CREATE TABLE public.categorias_evento (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  nombre character varying NOT NULL,
  icono character varying,
  CONSTRAINT categorias_evento_pkey PRIMARY KEY (id)
);
CREATE TABLE public.categorias_servicio (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  nombre character varying NOT NULL,
  descripcion character varying,
  icono character varying,
  activa boolean NOT NULL DEFAULT true,
  CONSTRAINT categorias_servicio_pkey PRIMARY KEY (id)
);
CREATE TABLE public.cotizaciones (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  solicitud_id uuid NOT NULL,
  proveedor_usuario_id uuid NOT NULL,
  precio_total_propuesto numeric NOT NULL,
  desglose_json jsonb,
  notas text,
  estado text NOT NULL DEFAULT 'pendiente'::text CHECK (estado = ANY (ARRAY['pendiente'::text, 'aceptada_cliente'::text, 'rechazada_cliente'::text])),
  creado_en timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT cotizaciones_pkey PRIMARY KEY (id),
  CONSTRAINT cotizaciones_solicitud_id_fkey FOREIGN KEY (solicitud_id) REFERENCES public.solicitudes(id)
);
CREATE TABLE public.historial_suscripciones (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  proveedor_usuario_id uuid NOT NULL,
  plan text NOT NULL CHECK (plan = ANY (ARRAY['basico'::text, 'plus'::text])),
  monto_pagado numeric NOT NULL,
  fecha_inicio timestamp with time zone NOT NULL,
  fecha_fin timestamp with time zone NOT NULL,
  estado_pago text NOT NULL DEFAULT 'pagado'::text CHECK (estado_pago = ANY (ARRAY['pagado'::text, 'pendiente'::text, 'fallido'::text])),
  metodo_pago character varying,
  referencia_transaccion character varying,
  creado_en timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT historial_suscripciones_pkey PRIMARY KEY (id)
);
CREATE TABLE public.items_carrito (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  carrito_id uuid NOT NULL,
  paquete_id uuid NOT NULL,
  cantidad integer NOT NULL DEFAULT 1,
  precio_unitario_momento numeric NOT NULL,
  creado_en timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT items_carrito_pkey PRIMARY KEY (id),
  CONSTRAINT items_carrito_carrito_id_fkey FOREIGN KEY (carrito_id) REFERENCES public.carrito(id),
  CONSTRAINT items_carrito_paquete_id_fkey FOREIGN KEY (paquete_id) REFERENCES public.paquetes_proveedor(id)
);
CREATE TABLE public.items_paquete (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  paquete_id uuid NOT NULL,
  nombre_item character varying NOT NULL,
  cantidad integer NOT NULL,
  unidad character varying,
  creado_en timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT items_paquete_pkey PRIMARY KEY (id),
  CONSTRAINT items_paquete_paquete_id_fkey FOREIGN KEY (paquete_id) REFERENCES public.paquetes_proveedor(id)
);
CREATE TABLE public.items_solicitud (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  solicitud_id uuid NOT NULL,
  paquete_id uuid,
  nombre_paquete_snapshot character varying NOT NULL,
  cantidad integer NOT NULL,
  precio_unitario numeric NOT NULL,
  CONSTRAINT items_solicitud_pkey PRIMARY KEY (id),
  CONSTRAINT items_solicitud_solicitud_id_fkey FOREIGN KEY (solicitud_id) REFERENCES public.solicitudes(id),
  CONSTRAINT items_solicitud_paquete_id_fkey FOREIGN KEY (paquete_id) REFERENCES public.paquetes_proveedor(id)
);
CREATE TABLE public.pagos (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  cotizacion_id uuid,
  cliente_usuario_id uuid NOT NULL,
  proveedor_usuario_id uuid NOT NULL,
  monto numeric NOT NULL,
  metodo_pago text NOT NULL CHECK (metodo_pago = ANY (ARRAY['transferencia'::text, 'efectivo'::text, 'deposito_oxxo'::text])),
  comprobante_url character varying,
  estado text NOT NULL DEFAULT 'esperando_comprobante'::text CHECK (estado = ANY (ARRAY['esperando_comprobante'::text, 'en_revision'::text, 'aprobado'::text, 'rechazado'::text])),
  motivo_rechazo character varying,
  creado_en timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
  actualizado_en timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
  solicitud_id uuid,
  id_transaccion_externa character varying,
  tipo_pago text CHECK (tipo_pago = ANY (ARRAY['anticipo'::text, 'liquidacion'::text])),
  CONSTRAINT pagos_pkey PRIMARY KEY (id),
  CONSTRAINT pagos_cotizacion_id_fkey FOREIGN KEY (cotizacion_id) REFERENCES public.cotizaciones(id),
  CONSTRAINT pagos_cliente_usuario_id_fkey FOREIGN KEY (cliente_usuario_id) REFERENCES public.users(id),
  CONSTRAINT pagos_solicitud_id_fkey FOREIGN KEY (solicitud_id) REFERENCES public.solicitudes(id)
);
CREATE TABLE public.paquetes_proveedor (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  proveedor_usuario_id uuid NOT NULL,
  categoria_servicio_id uuid NOT NULL,
  nombre character varying NOT NULL,
  descripcion text,
  precio_base numeric NOT NULL,
  estado text NOT NULL DEFAULT 'borrador'::text CHECK (estado = ANY (ARRAY['borrador'::text, 'publicado'::text, 'archivado'::text])),
  creado_en timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
  actualizado_en timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
  detalles_json jsonb,
  CONSTRAINT paquetes_proveedor_pkey PRIMARY KEY (id),
  CONSTRAINT paquetes_proveedor_categoria_servicio_id_fkey FOREIGN KEY (categoria_servicio_id) REFERENCES public.categorias_servicio(id)
);
CREATE TABLE public.perfil_cliente (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  usuario_id uuid NOT NULL,
  nombre_completo character varying NOT NULL,
  telefono character varying,
  avatar_url character varying,
  creado_en timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT perfil_cliente_pkey PRIMARY KEY (id),
  CONSTRAINT perfil_cliente_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.users(id)
);
CREATE TABLE public.perfil_proveedor (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  usuario_id uuid,
  nombre_negocio character varying NOT NULL,
  descripcion text,
  telefono character varying,
  avatar_url character varying,
  direccion_formato character varying,
  latitud numeric,
  longitud numeric,
  radio_cobertura_km integer DEFAULT 20,
  tipo_suscripcion_actual text NOT NULL DEFAULT 'basico'::text CHECK (tipo_suscripcion_actual = ANY (ARRAY['basico'::text, 'plus'::text])),
  categoria_principal_id uuid,
  creado_en timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
  actualizado_en timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
  correo_electronico character varying UNIQUE,
  contrasena character varying,
  estado text DEFAULT 'active'::text CHECK (estado = ANY (ARRAY['active'::text, 'blocked'::text])),
  datos_bancarios_json jsonb,
  CONSTRAINT perfil_proveedor_pkey PRIMARY KEY (id),
  CONSTRAINT perfil_proveedor_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.users(id),
  CONSTRAINT fk_perfil_proveedor_categoria FOREIGN KEY (categoria_principal_id) REFERENCES public.categorias_servicio(id)
);
CREATE TABLE public.resenas (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  solicitud_id uuid NOT NULL,
  autor_id uuid NOT NULL,
  destinatario_id uuid NOT NULL,
  calificacion smallint NOT NULL CHECK (calificacion >= 1 AND calificacion <= 5),
  comentario text,
  creado_en timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT resenas_pkey PRIMARY KEY (id),
  CONSTRAINT resenas_solicitud_id_fkey FOREIGN KEY (solicitud_id) REFERENCES public.solicitudes(id),
  CONSTRAINT resenas_autor_id_fkey FOREIGN KEY (autor_id) REFERENCES public.users(id),
  CONSTRAINT resenas_destinatario_id_fkey FOREIGN KEY (destinatario_id) REFERENCES public.users(id)
);
CREATE TABLE public.solicitudes (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  numero_solicitud integer GENERATED ALWAYS AS IDENTITY NOT NULL,
  cliente_usuario_id uuid NOT NULL,
  proveedor_usuario_id uuid NOT NULL,
  fecha_servicio date NOT NULL,
  direccion_servicio character varying NOT NULL,
  latitud_servicio numeric,
  longitud_servicio numeric,
  titulo_evento character varying,
  estado text NOT NULL DEFAULT 'pendiente_aprobacion'::text CHECK (estado = ANY (ARRAY['pendiente_aprobacion'::text, 'rechazada'::text, 'esperando_anticipo'::text, 'reservado'::text, 'en_progreso'::text, 'entregado_pendiente_liq'::text, 'finalizado'::text, 'cancelada'::text, 'abandonada'::text])),
  creado_en timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
  actualizado_en timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
  monto_total numeric DEFAULT 0,
  monto_anticipo numeric DEFAULT 0,
  monto_liquidacion numeric DEFAULT 0,
  link_pago_anticipo text,
  link_pago_liquidacion text,
  expiracion_anticipo timestamp with time zone,
  pin_seguridad character varying,
  pin_validado_en timestamp with time zone,
  CONSTRAINT solicitudes_pkey PRIMARY KEY (id),
  CONSTRAINT solicitudes_cliente_usuario_id_fkey FOREIGN KEY (cliente_usuario_id) REFERENCES public.users(id)
);
CREATE TABLE public.users (
  id uuid NOT NULL,
  correo_electronico character varying NOT NULL UNIQUE,
  contrasena character varying NOT NULL,
  rol text NOT NULL CHECK (rol = ANY (ARRAY['client'::text, 'provider'::text, 'admin'::text])),
  estado text NOT NULL DEFAULT 'active'::text CHECK (estado = ANY (ARRAY['active'::text, 'blocked'::text])),
  creado_en timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
  actualizado_en timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT users_pkey PRIMARY KEY (id)
);