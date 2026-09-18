export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  graphql_public: {
    Tables: {
      [_ in never]: never
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      graphql: {
        Args: {
          extensions?: Json
          operationName?: string
          query?: string
          variables?: Json
        }
        Returns: Json
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
  public: {
    Tables: {
      activity_logs: {
        Row: {
          action_type: Database["public"]["Enums"]["activity_action_type"]
          actor_profile_id: string | null
          client_id: string | null
          document_id: string | null
          driver_id: string | null
          expense_id: string | null
          id: string
          maintenance_record_id: string | null
          metadata: Json | null
          occurred_at: string
          shipment_id: string | null
          status_request_id: string | null
          vehicle_id: string | null
        }
        Insert: {
          action_type: Database["public"]["Enums"]["activity_action_type"]
          actor_profile_id?: string | null
          client_id?: string | null
          document_id?: string | null
          driver_id?: string | null
          expense_id?: string | null
          id: string
          maintenance_record_id?: string | null
          metadata?: Json | null
          occurred_at?: string
          shipment_id?: string | null
          status_request_id?: string | null
          vehicle_id?: string | null
        }
        Update: {
          action_type?: Database["public"]["Enums"]["activity_action_type"]
          actor_profile_id?: string | null
          client_id?: string | null
          document_id?: string | null
          driver_id?: string | null
          expense_id?: string | null
          id?: string
          maintenance_record_id?: string | null
          metadata?: Json | null
          occurred_at?: string
          shipment_id?: string | null
          status_request_id?: string | null
          vehicle_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "activity_logs_actor_profile_id_fkey"
            columns: ["actor_profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "activity_logs_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "clients"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "activity_logs_document_id_fkey"
            columns: ["document_id"]
            isOneToOne: false
            referencedRelation: "documents"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "activity_logs_driver_id_fkey"
            columns: ["driver_id"]
            isOneToOne: false
            referencedRelation: "drivers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "activity_logs_expense_id_fkey"
            columns: ["expense_id"]
            isOneToOne: false
            referencedRelation: "expenses"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "activity_logs_maintenance_record_id_fkey"
            columns: ["maintenance_record_id"]
            isOneToOne: false
            referencedRelation: "maintenance_records"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "activity_logs_shipment_id_fkey"
            columns: ["shipment_id"]
            isOneToOne: false
            referencedRelation: "shipments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "activity_logs_status_request_id_fkey"
            columns: ["status_request_id"]
            isOneToOne: false
            referencedRelation: "shipment_status_requests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "activity_logs_vehicle_id_fkey"
            columns: ["vehicle_id"]
            isOneToOne: false
            referencedRelation: "vehicles"
            referencedColumns: ["id"]
          },
        ]
      }
      alerts: {
        Row: {
          alert_state: Database["public"]["Enums"]["alert_state"]
          alert_type: Database["public"]["Enums"]["alert_type"]
          created_at: string
          document_id: string | null
          driver_id: string | null
          id: string
          message: string
          resolved_at: string | null
          resolved_by_profile_id: string | null
          severity: Database["public"]["Enums"]["alert_severity"]
          shipment_id: string | null
          vehicle_id: string | null
        }
        Insert: {
          alert_state?: Database["public"]["Enums"]["alert_state"]
          alert_type: Database["public"]["Enums"]["alert_type"]
          created_at?: string
          document_id?: string | null
          driver_id?: string | null
          id: string
          message: string
          resolved_at?: string | null
          resolved_by_profile_id?: string | null
          severity: Database["public"]["Enums"]["alert_severity"]
          shipment_id?: string | null
          vehicle_id?: string | null
        }
        Update: {
          alert_state?: Database["public"]["Enums"]["alert_state"]
          alert_type?: Database["public"]["Enums"]["alert_type"]
          created_at?: string
          document_id?: string | null
          driver_id?: string | null
          id?: string
          message?: string
          resolved_at?: string | null
          resolved_by_profile_id?: string | null
          severity?: Database["public"]["Enums"]["alert_severity"]
          shipment_id?: string | null
          vehicle_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "alerts_document_id_fkey"
            columns: ["document_id"]
            isOneToOne: false
            referencedRelation: "documents"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "alerts_driver_id_fkey"
            columns: ["driver_id"]
            isOneToOne: false
            referencedRelation: "drivers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "alerts_resolved_by_profile_id_fkey"
            columns: ["resolved_by_profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "alerts_shipment_id_fkey"
            columns: ["shipment_id"]
            isOneToOne: false
            referencedRelation: "shipments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "alerts_vehicle_id_fkey"
            columns: ["vehicle_id"]
            isOneToOne: false
            referencedRelation: "vehicles"
            referencedColumns: ["id"]
          },
        ]
      }
      clients: {
        Row: {
          address: string | null
          company_name: string
          contact_person: string | null
          created_at: string
          email: string | null
          id: string
          notes: string | null
          phone: string | null
          status: Database["public"]["Enums"]["client_status"]
          updated_at: string
        }
        Insert: {
          address?: string | null
          company_name: string
          contact_person?: string | null
          created_at?: string
          email?: string | null
          id: string
          notes?: string | null
          phone?: string | null
          status?: Database["public"]["Enums"]["client_status"]
          updated_at?: string
        }
        Update: {
          address?: string | null
          company_name?: string
          contact_person?: string | null
          created_at?: string
          email?: string | null
          id?: string
          notes?: string | null
          phone?: string | null
          status?: Database["public"]["Enums"]["client_status"]
          updated_at?: string
        }
        Relationships: []
      }
      documents: {
        Row: {
          document_type: string
          driver_id: string | null
          file_name: string
          file_path: string
          id: string
          lifecycle_status: Database["public"]["Enums"]["document_lifecycle_status"]
          shipment_id: string | null
          updated_at: string
          uploaded_at: string
          uploader_profile_id: string
          valid_from: string | null
          valid_until: string | null
          vehicle_id: string | null
        }
        Insert: {
          document_type: string
          driver_id?: string | null
          file_name: string
          file_path: string
          id: string
          lifecycle_status?: Database["public"]["Enums"]["document_lifecycle_status"]
          shipment_id?: string | null
          updated_at?: string
          uploaded_at?: string
          uploader_profile_id: string
          valid_from?: string | null
          valid_until?: string | null
          vehicle_id?: string | null
        }
        Update: {
          document_type?: string
          driver_id?: string | null
          file_name?: string
          file_path?: string
          id?: string
          lifecycle_status?: Database["public"]["Enums"]["document_lifecycle_status"]
          shipment_id?: string | null
          updated_at?: string
          uploaded_at?: string
          uploader_profile_id?: string
          valid_from?: string | null
          valid_until?: string | null
          vehicle_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "documents_driver_id_fkey"
            columns: ["driver_id"]
            isOneToOne: false
            referencedRelation: "drivers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "documents_shipment_id_fkey"
            columns: ["shipment_id"]
            isOneToOne: false
            referencedRelation: "shipments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "documents_uploader_profile_id_fkey"
            columns: ["uploader_profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "documents_vehicle_id_fkey"
            columns: ["vehicle_id"]
            isOneToOne: false
            referencedRelation: "vehicles"
            referencedColumns: ["id"]
          },
        ]
      }
      drivers: {
        Row: {
          created_at: string
          id: string
          phone: string | null
          profile_id: string
          status: Database["public"]["Enums"]["driver_status"]
          updated_at: string
        }
        Insert: {
          created_at?: string
          id: string
          phone?: string | null
          profile_id: string
          status: Database["public"]["Enums"]["driver_status"]
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: string
          phone?: string | null
          profile_id?: string
          status?: Database["public"]["Enums"]["driver_status"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "drivers_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: true
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      expenses: {
        Row: {
          amount: number
          category: Database["public"]["Enums"]["expense_category"]
          created_at: string
          created_by_profile_id: string
          description: string | null
          expense_date: string
          id: string
          shipment_id: string
          updated_at: string
        }
        Insert: {
          amount: number
          category: Database["public"]["Enums"]["expense_category"]
          created_at?: string
          created_by_profile_id: string
          description?: string | null
          expense_date: string
          id: string
          shipment_id: string
          updated_at?: string
        }
        Update: {
          amount?: number
          category?: Database["public"]["Enums"]["expense_category"]
          created_at?: string
          created_by_profile_id?: string
          description?: string | null
          expense_date?: string
          id?: string
          shipment_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "expenses_created_by_profile_id_fkey"
            columns: ["created_by_profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "expenses_shipment_id_fkey"
            columns: ["shipment_id"]
            isOneToOne: false
            referencedRelation: "shipments"
            referencedColumns: ["id"]
          },
        ]
      }
      maintenance_records: {
        Row: {
          cost: number | null
          created_at: string
          id: string
          mileage_at_service: number
          next_service_date: string | null
          next_service_mileage: number | null
          notes: string | null
          service_date: string
          service_type: string
          updated_at: string
          vehicle_id: string
          workshop: string | null
        }
        Insert: {
          cost?: number | null
          created_at?: string
          id: string
          mileage_at_service: number
          next_service_date?: string | null
          next_service_mileage?: number | null
          notes?: string | null
          service_date: string
          service_type: string
          updated_at?: string
          vehicle_id: string
          workshop?: string | null
        }
        Update: {
          cost?: number | null
          created_at?: string
          id?: string
          mileage_at_service?: number
          next_service_date?: string | null
          next_service_mileage?: number | null
          notes?: string | null
          service_date?: string
          service_type?: string
          updated_at?: string
          vehicle_id?: string
          workshop?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "maintenance_records_vehicle_id_fkey"
            columns: ["vehicle_id"]
            isOneToOne: false
            referencedRelation: "vehicles"
            referencedColumns: ["id"]
          },
        ]
      }
      messages: {
        Row: {
          body: string
          id: string
          read_at: string | null
          recipient_driver_id: string
          sender_profile_id: string
          sent_at: string
          shipment_id: string | null
        }
        Insert: {
          body: string
          id: string
          read_at?: string | null
          recipient_driver_id: string
          sender_profile_id: string
          sent_at?: string
          shipment_id?: string | null
        }
        Update: {
          body?: string
          id?: string
          read_at?: string | null
          recipient_driver_id?: string
          sender_profile_id?: string
          sent_at?: string
          shipment_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "messages_recipient_driver_id_fkey"
            columns: ["recipient_driver_id"]
            isOneToOne: false
            referencedRelation: "drivers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "messages_sender_profile_id_fkey"
            columns: ["sender_profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "messages_shipment_id_fkey"
            columns: ["shipment_id"]
            isOneToOne: false
            referencedRelation: "shipments"
            referencedColumns: ["id"]
          },
        ]
      }
      notifications: {
        Row: {
          created_at: string
          document_id: string | null
          driver_id: string | null
          id: string
          message: string
          notification_type: Database["public"]["Enums"]["notification_type"]
          read_at: string | null
          recipient_profile_id: string
          shipment_id: string | null
          title: string
          vehicle_id: string | null
        }
        Insert: {
          created_at?: string
          document_id?: string | null
          driver_id?: string | null
          id: string
          message: string
          notification_type: Database["public"]["Enums"]["notification_type"]
          read_at?: string | null
          recipient_profile_id: string
          shipment_id?: string | null
          title: string
          vehicle_id?: string | null
        }
        Update: {
          created_at?: string
          document_id?: string | null
          driver_id?: string | null
          id?: string
          message?: string
          notification_type?: Database["public"]["Enums"]["notification_type"]
          read_at?: string | null
          recipient_profile_id?: string
          shipment_id?: string | null
          title?: string
          vehicle_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "notifications_document_id_fkey"
            columns: ["document_id"]
            isOneToOne: false
            referencedRelation: "documents"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notifications_driver_id_fkey"
            columns: ["driver_id"]
            isOneToOne: false
            referencedRelation: "drivers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notifications_recipient_profile_id_fkey"
            columns: ["recipient_profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notifications_shipment_id_fkey"
            columns: ["shipment_id"]
            isOneToOne: false
            referencedRelation: "shipments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notifications_vehicle_id_fkey"
            columns: ["vehicle_id"]
            isOneToOne: false
            referencedRelation: "vehicles"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          created_at: string
          full_name: string
          id: string
          is_active: boolean
          role: Database["public"]["Enums"]["profile_role"]
          updated_at: string
          username: string
        }
        Insert: {
          created_at?: string
          full_name: string
          id: string
          is_active?: boolean
          role: Database["public"]["Enums"]["profile_role"]
          updated_at?: string
          username: string
        }
        Update: {
          created_at?: string
          full_name?: string
          id?: string
          is_active?: boolean
          role?: Database["public"]["Enums"]["profile_role"]
          updated_at?: string
          username?: string
        }
        Relationships: []
      }
      shipment_status_requests: {
        Row: {
          current_status: Database["public"]["Enums"]["shipment_status"]
          driver_id: string
          id: string
          rejection_reason: string | null
          request_state: Database["public"]["Enums"]["status_request_state"]
          requested_at: string
          requested_status: Database["public"]["Enums"]["shipment_status"]
          resolved_at: string | null
          resolved_by_profile_id: string | null
          shipment_id: string
          updated_at: string
        }
        Insert: {
          current_status: Database["public"]["Enums"]["shipment_status"]
          driver_id: string
          id: string
          rejection_reason?: string | null
          request_state?: Database["public"]["Enums"]["status_request_state"]
          requested_at?: string
          requested_status: Database["public"]["Enums"]["shipment_status"]
          resolved_at?: string | null
          resolved_by_profile_id?: string | null
          shipment_id: string
          updated_at?: string
        }
        Update: {
          current_status?: Database["public"]["Enums"]["shipment_status"]
          driver_id?: string
          id?: string
          rejection_reason?: string | null
          request_state?: Database["public"]["Enums"]["status_request_state"]
          requested_at?: string
          requested_status?: Database["public"]["Enums"]["shipment_status"]
          resolved_at?: string | null
          resolved_by_profile_id?: string | null
          shipment_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "shipment_status_requests_driver_id_fkey"
            columns: ["driver_id"]
            isOneToOne: false
            referencedRelation: "drivers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shipment_status_requests_resolved_by_profile_id_fkey"
            columns: ["resolved_by_profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shipment_status_requests_shipment_id_fkey"
            columns: ["shipment_id"]
            isOneToOne: false
            referencedRelation: "shipments"
            referencedColumns: ["id"]
          },
        ]
      }
      shipments: {
        Row: {
          cargo_type: string
          client_id: string
          created_at: string
          delayed: boolean
          delivery_address: string
          driver_id: string | null
          expected_delivery_at: string
          id: string
          pickup_address: string
          pickup_at: string
          price: number
          status: Database["public"]["Enums"]["shipment_status"]
          tracking_number: string
          updated_at: string
          vehicle_id: string | null
        }
        Insert: {
          cargo_type: string
          client_id: string
          created_at?: string
          delayed?: boolean
          delivery_address: string
          driver_id?: string | null
          expected_delivery_at: string
          id: string
          pickup_address: string
          pickup_at: string
          price: number
          status?: Database["public"]["Enums"]["shipment_status"]
          tracking_number: string
          updated_at?: string
          vehicle_id?: string | null
        }
        Update: {
          cargo_type?: string
          client_id?: string
          created_at?: string
          delayed?: boolean
          delivery_address?: string
          driver_id?: string | null
          expected_delivery_at?: string
          id?: string
          pickup_address?: string
          pickup_at?: string
          price?: number
          status?: Database["public"]["Enums"]["shipment_status"]
          tracking_number?: string
          updated_at?: string
          vehicle_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "shipments_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "clients"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shipments_driver_id_fkey"
            columns: ["driver_id"]
            isOneToOne: false
            referencedRelation: "drivers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shipments_vehicle_id_fkey"
            columns: ["vehicle_id"]
            isOneToOne: false
            referencedRelation: "vehicles"
            referencedColumns: ["id"]
          },
        ]
      }
      tracking_history: {
        Row: {
          heading: number | null
          id: string
          latitude: number
          longitude: number
          recorded_at: string
          route_progress: number | null
          shipment_id: string
          speed: number | null
          vehicle_id: string
        }
        Insert: {
          heading?: number | null
          id: string
          latitude: number
          longitude: number
          recorded_at?: string
          route_progress?: number | null
          shipment_id: string
          speed?: number | null
          vehicle_id: string
        }
        Update: {
          heading?: number | null
          id?: string
          latitude?: number
          longitude?: number
          recorded_at?: string
          route_progress?: number | null
          shipment_id?: string
          speed?: number | null
          vehicle_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "tracking_history_shipment_id_fkey"
            columns: ["shipment_id"]
            isOneToOne: false
            referencedRelation: "shipments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tracking_history_vehicle_id_fkey"
            columns: ["vehicle_id"]
            isOneToOne: false
            referencedRelation: "vehicles"
            referencedColumns: ["id"]
          },
        ]
      }
      vehicle_locations: {
        Row: {
          heading: number | null
          latitude: number
          longitude: number
          route_progress: number | null
          shipment_id: string
          speed: number | null
          updated_at: string
          vehicle_id: string
        }
        Insert: {
          heading?: number | null
          latitude: number
          longitude: number
          route_progress?: number | null
          shipment_id: string
          speed?: number | null
          updated_at?: string
          vehicle_id: string
        }
        Update: {
          heading?: number | null
          latitude?: number
          longitude?: number
          route_progress?: number | null
          shipment_id?: string
          speed?: number | null
          updated_at?: string
          vehicle_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "vehicle_locations_shipment_id_fkey"
            columns: ["shipment_id"]
            isOneToOne: true
            referencedRelation: "shipments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "vehicle_locations_vehicle_id_fkey"
            columns: ["vehicle_id"]
            isOneToOne: true
            referencedRelation: "vehicles"
            referencedColumns: ["id"]
          },
        ]
      }
      vehicles: {
        Row: {
          created_at: string
          first_registration_date: string | null
          fuel_type: string | null
          id: string
          make: string
          mileage: number
          model: string
          registration: string
          status: Database["public"]["Enums"]["vehicle_status"]
          updated_at: string
          vehicle_type: string
          vin: string | null
        }
        Insert: {
          created_at?: string
          first_registration_date?: string | null
          fuel_type?: string | null
          id: string
          make: string
          mileage?: number
          model: string
          registration: string
          status: Database["public"]["Enums"]["vehicle_status"]
          updated_at?: string
          vehicle_type: string
          vin?: string | null
        }
        Update: {
          created_at?: string
          first_registration_date?: string | null
          fuel_type?: string | null
          id?: string
          make?: string
          mileage?: number
          model?: string
          registration?: string
          status?: Database["public"]["Enums"]["vehicle_status"]
          updated_at?: string
          vehicle_type?: string
          vin?: string | null
        }
        Relationships: []
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      acknowledge_driver_message: {
        Args: { message_id: string }
        Returns: string
      }
      acknowledge_notification: {
        Args: { notification_id: string }
        Returns: string
      }
      approve_shipment_status_request: {
        Args: { target_request_id: string }
        Returns: {
          request_state: Database["public"]["Enums"]["status_request_state"]
          shipment_status: Database["public"]["Enums"]["shipment_status"]
        }[]
      }
      assign_pending_shipment: {
        Args: {
          target_driver_id: string
          target_shipment_id: string
          target_vehicle_id: string
        }
        Returns: {
          id: string
          tracking_number: string
        }[]
      }
      auth_username_local_part: { Args: { username: string }; Returns: string }
      authorize_document_upload_intent: {
        Args: {
          input_document_type: string
          owner_kind: string
          target_owner_id: string
        }
        Returns: boolean
      }
      cancel_shipment: {
        Args: { target_shipment_id: string }
        Returns: {
          id: string
          previous_status: Database["public"]["Enums"]["shipment_status"]
          shipment_status: Database["public"]["Enums"]["shipment_status"]
          tracking_number: string
        }[]
      }
      change_driver_operational_status: {
        Args: { requested_operation: string; target_driver_id: string }
        Returns: Database["public"]["Enums"]["driver_status"]
      }
      change_vehicle_operational_status: {
        Args: { requested_operation: string; target_vehicle_id: string }
        Returns: Database["public"]["Enums"]["vehicle_status"]
      }
      complete_document_upload: {
        Args: {
          input_document_type: string
          input_file_name: string
          input_file_path: string
          input_valid_from?: string
          input_valid_until?: string
          owner_kind: string
          target_document_id: string
          target_owner_id: string
        }
        Returns: string
      }
      create_maintenance_record: {
        Args: {
          input_cost?: number
          input_mileage_at_service: number
          input_next_service_date?: string
          input_next_service_mileage?: number
          input_notes?: string
          input_service_date: string
          input_service_type: string
          input_workshop?: string
          target_vehicle_id: string
        }
        Returns: string
      }
      create_pending_shipment: {
        Args: {
          input_cargo_type: string
          input_client_id: string
          input_delivery_address: string
          input_expected_delivery_at: string
          input_pickup_address: string
          input_pickup_at: string
          input_price: number
        }
        Returns: {
          id: string
          tracking_number: string
        }[]
      }
      create_shipment_status_request: {
        Args: {
          requested_status: Database["public"]["Enums"]["shipment_status"]
        }
        Returns: {
          accepted_status: Database["public"]["Enums"]["shipment_status"]
          request_state: Database["public"]["Enums"]["status_request_state"]
        }[]
      }
      create_vehicle: {
        Args: {
          input_first_registration_date?: string
          input_fuel_type?: string
          input_make: string
          input_mileage?: number
          input_model: string
          input_registration: string
          input_vehicle_type: string
          input_vin?: string
        }
        Returns: string
      }
      current_active_profile_role: {
        Args: never
        Returns: Database["public"]["Enums"]["profile_role"]
      }
      document_type_allowed: {
        Args: { candidate: string; owner_kind: string }
        Returns: boolean
      }
      get_current_driver_status_request: {
        Args: never
        Returns: {
          current_status: Database["public"]["Enums"]["shipment_status"]
          rejection_reason: string
          request_state: Database["public"]["Enums"]["status_request_state"]
          requested_at: string
          requested_status: Database["public"]["Enums"]["shipment_status"]
          resolved_at: string
        }[]
      }
      get_operations_dashboard_kpis: {
        Args: never
        Returns: {
          active_alerts: number
          active_shipments: number
          assigned_drivers: number
          in_use_vehicles: number
        }[]
      }
      get_operations_document_for_edit: {
        Args: { target_document_id: string }
        Returns: {
          document_type: string
          id: string
          owner_label: string
          owner_type: string
          updated_at: string
          valid_from: string
          valid_until: string
        }[]
      }
      get_operations_maintenance_for_edit: {
        Args: { target_maintenance_record_id: string }
        Returns: {
          cost: number
          created_at: string
          id: string
          mileage_at_service: number
          next_service_date: string
          next_service_mileage: number
          notes: string
          service_date: string
          service_type: string
          updated_at: string
          vehicle_id: string
          vehicle_registration: string
          workshop: string
        }[]
      }
      get_operations_shipment_for_edit: {
        Args: { target_shipment_id: string }
        Returns: {
          cargo_type: string
          delivery_address: string
          expected_delivery_at: string
          id: string
          pickup_address: string
          pickup_at: string
          price: number
          status: Database["public"]["Enums"]["shipment_status"]
          tracking_number: string
          updated_at: string
        }[]
      }
      get_operations_vehicle_for_edit: {
        Args: { target_vehicle_id: string }
        Returns: {
          first_registration_date: string
          fuel_type: string
          id: string
          make: string
          mileage: number
          model: string
          registration: string
          status: Database["public"]["Enums"]["vehicle_status"]
          updated_at: string
          vehicle_type: string
          vin: string
        }[]
      }
      list_abandoned_document_objects: {
        Args: { after_object_name?: string }
        Returns: {
          object_name: string
        }[]
      }
      list_active_shipment_clients: {
        Args: never
        Returns: {
          company_name: string
          id: string
        }[]
      }
      list_document_alert_ids: {
        Args: { after_document_id?: string }
        Returns: {
          document_id: string
        }[]
      }
      list_document_owner_options: {
        Args: { owner_kind: string }
        Returns: {
          id: string
          label: string
        }[]
      }
      list_eligible_shipment_drivers: {
        Args: never
        Returns: {
          display_name: string
          id: string
        }[]
      }
      list_eligible_shipment_vehicles: {
        Args: never
        Returns: {
          id: string
          make: string
          model: string
          registration: string
        }[]
      }
      list_maintenance_alert_vehicle_ids: {
        Args: { after_vehicle_id?: string }
        Returns: {
          vehicle_id: string
        }[]
      }
      list_maintenance_vehicle_options: {
        Args: never
        Returns: {
          id: string
          registration: string
        }[]
      }
      list_managed_accounts: {
        Args: {
          active_filter?: boolean
          page_limit?: number
          page_offset?: number
          role_filter?: Database["public"]["Enums"]["profile_role"]
          search_query?: string
        }
        Returns: Json
      }
      list_message_recipient_options: {
        Args: never
        Returns: {
          display_name: string
          id: string
        }[]
      }
      list_message_shipment_options: {
        Args: never
        Returns: {
          driver_id: string
          id: string
          status: Database["public"]["Enums"]["shipment_status"]
          tracking_number: string
        }[]
      }
      list_operations_dashboard_pending_status_requests: {
        Args: { preview_limit: number }
        Returns: {
          current_status: Database["public"]["Enums"]["shipment_status"]
          driver_name: string
          id: string
          requested_at: string
          requested_status: Database["public"]["Enums"]["shipment_status"]
          tracking_number: string
        }[]
      }
      list_operations_documents: {
        Args: {
          lifecycle_filter?: string
          owner_filter?: string
          requested_page?: number
          search_text?: string
          type_filter?: string
          validity_filter?: string
        }
        Returns: {
          derived_status: string
          document_type: string
          file_name: string
          id: string
          lifecycle_status: Database["public"]["Enums"]["document_lifecycle_status"]
          owner_label: string
          owner_type: string
          total_count: number
          updated_at: string
          uploaded_at: string
          valid_from: string
          valid_until: string
        }[]
      }
      list_operations_maintenance: {
        Args: {
          requested_page?: number
          search_text?: string
          service_date_from?: string
          service_date_to?: string
          vehicle_filter?: string
        }
        Returns: {
          cost: number
          id: string
          mileage_at_service: number
          next_service_date: string
          next_service_mileage: number
          service_date: string
          service_type: string
          total_count: number
          vehicle_registration: string
          workshop: string
        }[]
      }
      list_operations_pending_status_requests: {
        Args: never
        Returns: {
          current_status: Database["public"]["Enums"]["shipment_status"]
          driver_name: string
          id: string
          requested_at: string
          requested_status: Database["public"]["Enums"]["shipment_status"]
          tracking_number: string
        }[]
      }
      list_operations_shipments: {
        Args: {
          delayed_filter?: string
          requested_page?: number
          search_text?: string
          status_filter?: string
        }
        Returns: {
          client_company: string
          delayed: boolean
          delivery_address: string
          driver_name: string
          id: string
          pickup_address: string
          status: Database["public"]["Enums"]["shipment_status"]
          total_count: number
          tracking_number: string
          updated_at: string
          vehicle_registration: string
        }[]
      }
      list_operations_vehicle_types: {
        Args: never
        Returns: {
          vehicle_type: string
        }[]
      }
      list_operations_vehicles: {
        Args: {
          requested_page?: number
          search_text?: string
          status_filter?: string
          type_filter?: string
        }
        Returns: {
          id: string
          make: string
          mileage: number
          model: string
          registration: string
          status: Database["public"]["Enums"]["vehicle_status"]
          total_count: number
          vehicle_type: string
        }[]
      }
      list_tracking_simulation_shipments: {
        Args: never
        Returns: {
          shipment_id: string
        }[]
      }
      provision_account_profile: {
        Args: {
          auth_user_id: string
          driver_id?: string
          full_name: string
          provisioned_role: string
          username: string
        }
        Returns: undefined
      }
      reconcile_document_expiry_alerts: {
        Args: {
          lifecycle_actor_profile_id?: string
          target_document_id: string
        }
        Returns: {
          created_count: number
          resolved_count: number
          updated_count: number
        }[]
      }
      reconcile_stale_vehicle_locations: {
        Args: never
        Returns: {
          created_count: number
          resolved_count: number
        }[]
      }
      reconcile_vehicle_maintenance_alerts: {
        Args: { lifecycle_actor_profile_id?: string; target_vehicle_id: string }
        Returns: {
          created_count: number
          resolved_count: number
          updated_count: number
        }[]
      }
      reject_shipment_status_request: {
        Args: { input_rejection_reason?: string; target_request_id: string }
        Returns: {
          request_state: Database["public"]["Enums"]["status_request_state"]
          requested_status: Database["public"]["Enums"]["shipment_status"]
        }[]
      }
      resolve_managed_account: {
        Args: { target_username: string }
        Returns: {
          account_id: string
          account_is_active: boolean
          account_role: Database["public"]["Enums"]["profile_role"]
          account_username: string
        }[]
      }
      send_driver_message: {
        Args: {
          input_body: string
          target_driver_id: string
          target_shipment_id: string
        }
        Returns: {
          message_id: string
          notification_id: string
          sent_at: string
        }[]
      }
      set_document_lifecycle: {
        Args: {
          expected_updated_at: string
          requested_status: Database["public"]["Enums"]["document_lifecycle_status"]
          target_document_id: string
        }
        Returns: string
      }
      set_managed_account_active_state: {
        Args: { requested_active: boolean; target_username: string }
        Returns: {
          account_is_active: boolean
          account_role: Database["public"]["Enums"]["profile_role"]
        }[]
      }
      set_shipment_delayed: {
        Args: {
          expected_updated_at: string
          target_delayed: boolean
          target_shipment_id: string
        }
        Returns: {
          delayed: boolean
          mutation_result: string
          shipment_id: string
          updated_at: string
        }[]
      }
      simulate_tracking_step: {
        Args: { route_coordinates: Json; target_shipment_id: string }
        Returns: {
          step_result: string
        }[]
      }
      start_shipment_tracking: {
        Args: {
          actor_profile_id: string
          target_shipment_id: string
          target_vehicle_id: string
        }
        Returns: undefined
      }
      stop_shipment_tracking:
        | {
            Args: {
              actor_profile_id: string
              target_shipment_id: string
              target_vehicle_id: string
            }
            Returns: undefined
          }
        | {
            Args: {
              actor_profile_id: string
              target_shipment_id: string
              target_vehicle_id: string
              tracking_source: string
            }
            Returns: undefined
          }
      update_document_metadata: {
        Args: {
          expected_updated_at: string
          input_document_type: string
          input_valid_from?: string
          input_valid_until?: string
          target_document_id: string
        }
        Returns: string
      }
      update_maintenance_record: {
        Args: {
          expected_updated_at: string
          input_cost?: number
          input_mileage_at_service: number
          input_next_service_date?: string
          input_next_service_mileage?: number
          input_notes?: string
          input_service_date: string
          input_service_type: string
          input_workshop?: string
          target_maintenance_record_id: string
        }
        Returns: string
      }
      update_shipment_details: {
        Args: {
          expected_updated_at: string
          input_cargo_type: string
          input_delivery_address: string
          input_expected_delivery_at: string
          input_pickup_address: string
          input_pickup_at: string
          input_price?: number
          target_shipment_id: string
        }
        Returns: {
          id: string
          mutated: boolean
          tracking_number: string
          updated_at: string
        }[]
      }
      update_vehicle_master_data: {
        Args: {
          expected_updated_at: string
          input_first_registration_date?: string
          input_fuel_type?: string
          input_make: string
          input_model: string
          input_registration: string
          input_vehicle_type: string
          input_vin?: string
          target_vehicle_id: string
        }
        Returns: string
      }
      update_vehicle_mileage: {
        Args: {
          expected_updated_at: string
          new_mileage: number
          target_vehicle_id: string
        }
        Returns: string
      }
    }
    Enums: {
      activity_action_type:
        | "driver_created"
        | "driver_status_changed"
        | "client_created"
        | "client_updated"
        | "client_archived"
        | "client_reactivated"
        | "vehicle_created"
        | "vehicle_updated"
        | "vehicle_status_changed"
        | "vehicle_archived"
        | "shipment_created"
        | "shipment_updated"
        | "shipment_assigned"
        | "shipment_status_changed"
        | "shipment_delayed"
        | "shipment_cancelled"
        | "status_request_created"
        | "status_request_approved"
        | "status_request_rejected"
        | "document_uploaded"
        | "document_archived"
        | "document_restored"
        | "maintenance_record_created"
        | "maintenance_record_updated"
        | "expense_created"
        | "expense_updated"
        | "alert_created"
        | "alert_resolved"
        | "tracking_started"
        | "tracking_stopped"
      alert_severity: "info" | "warning" | "critical"
      alert_state: "active" | "resolved"
      alert_type:
        | "shipment_delayed"
        | "document_expiring"
        | "document_expired"
        | "maintenance_due_date"
        | "maintenance_due_mileage"
        | "stale_vehicle_location"
      client_status: "active" | "archived"
      document_lifecycle_status: "active" | "archived"
      driver_status:
        | "available"
        | "assigned"
        | "off_duty"
        | "inactive"
        | "archived"
      expense_category: "fuel" | "toll" | "driver" | "maintenance" | "other"
      notification_type:
        | "shipment_assigned"
        | "status_approval_requested"
        | "status_approved"
        | "status_rejected"
        | "shipment_delayed"
        | "vehicle_maintenance_due"
        | "vehicle_document_expiring"
        | "driver_document_expiring"
        | "new_dispatcher_message"
        | "shipment_delivered"
        | "shipment_cancelled"
      profile_role: "admin" | "dispatcher" | "driver"
      shipment_status:
        | "pending"
        | "assigned"
        | "loading"
        | "in_transit"
        | "delivered"
        | "cancelled"
      status_request_state: "pending" | "approved" | "rejected"
      vehicle_status:
        | "available"
        | "in_use"
        | "maintenance"
        | "out_of_service"
        | "archived"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  graphql_public: {
    Enums: {},
  },
  public: {
    Enums: {
      activity_action_type: [
        "driver_created",
        "driver_status_changed",
        "client_created",
        "client_updated",
        "client_archived",
        "client_reactivated",
        "vehicle_created",
        "vehicle_updated",
        "vehicle_status_changed",
        "vehicle_archived",
        "shipment_created",
        "shipment_updated",
        "shipment_assigned",
        "shipment_status_changed",
        "shipment_delayed",
        "shipment_cancelled",
        "status_request_created",
        "status_request_approved",
        "status_request_rejected",
        "document_uploaded",
        "document_archived",
        "document_restored",
        "maintenance_record_created",
        "maintenance_record_updated",
        "expense_created",
        "expense_updated",
        "alert_created",
        "alert_resolved",
        "tracking_started",
        "tracking_stopped",
      ],
      alert_severity: ["info", "warning", "critical"],
      alert_state: ["active", "resolved"],
      alert_type: [
        "shipment_delayed",
        "document_expiring",
        "document_expired",
        "maintenance_due_date",
        "maintenance_due_mileage",
        "stale_vehicle_location",
      ],
      client_status: ["active", "archived"],
      document_lifecycle_status: ["active", "archived"],
      driver_status: [
        "available",
        "assigned",
        "off_duty",
        "inactive",
        "archived",
      ],
      expense_category: ["fuel", "toll", "driver", "maintenance", "other"],
      notification_type: [
        "shipment_assigned",
        "status_approval_requested",
        "status_approved",
        "status_rejected",
        "shipment_delayed",
        "vehicle_maintenance_due",
        "vehicle_document_expiring",
        "driver_document_expiring",
        "new_dispatcher_message",
        "shipment_delivered",
        "shipment_cancelled",
      ],
      profile_role: ["admin", "dispatcher", "driver"],
      shipment_status: [
        "pending",
        "assigned",
        "loading",
        "in_transit",
        "delivered",
        "cancelled",
      ],
      status_request_state: ["pending", "approved", "rejected"],
      vehicle_status: [
        "available",
        "in_use",
        "maintenance",
        "out_of_service",
        "archived",
      ],
    },
  },
} as const
