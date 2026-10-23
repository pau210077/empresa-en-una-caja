variable "proyecto" {
  description = "Nombre del proyecto. Va en la etiqueta obligatoria 'proyecto'."
  type        = string
  default     = "empresa-en-una-caja"
}

variable "empresa" {
  description = "Nombre de la empresa ficticia (gestoría de 15 empleados)."
  type        = string
  default     = "Gestoría Hortensia Demo S.L."
}

variable "entorno" {
  description = "Entorno (etiqueta y sufijo de nombres)."
  type        = string
  default     = "demo"
}

variable "propietario" {
  description = "Propietario (etiqueta)."
  type        = string
  default     = "pau-miro"
}

variable "ubicacion" {
  description = "Región de Azure. Spain Central está permitida por la política."
  type        = string
  default     = "spaincentral"
}

variable "email_alertas" {
  description = "Email de alertas y presupuesto. Viene de la variable ALERT_EMAIL de GitHub, nunca va escrito aquí."
  type        = string
  sensitive   = true
}

variable "presupuesto_eur" {
  description = "Presupuesto mensual en euros del grupo de recursos."
  type        = number
  default     = 1
}

variable "inicio_presupuesto" {
  description = "Fecha de inicio del presupuesto. Tiene que ser el día 1 de un mes que no esté ya pasado."
  type        = string
  default     = "2026-11-01T00:00:00Z"
}

variable "hora_apagado" {
  description = "Hora de apagado automático de la VM (formato HHMM, hora de Madrid)."
  type        = string
  default     = "2300"
}
