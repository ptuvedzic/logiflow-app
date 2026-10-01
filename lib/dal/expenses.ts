import "server-only";

import type { ExpenseCreateInput, ExpenseEditInput } from "@/features/expenses/expense-schema";
import { createClient } from "@/lib/supabase/server";
import type { Database } from "@/types/database.generated";

type ShipmentStatus = Database["public"]["Enums"]["shipment_status"];
type ExpenseCategory = Database["public"]["Enums"]["expense_category"];
type ExpenseError = Readonly<{
  category: "forbidden" | "not_found" | "conflict" | "business_rule" | "infrastructure";
  message: string;
}>;

export type ExpenseResult<T> =
  | Readonly<{ ok: true; data: T }>
  | Readonly<{ ok: false; error: ExpenseError }>;

export type ShipmentFinancialDetail = Readonly<{
  id: string;
  trackingNumber: string;
  status: ShipmentStatus;
  delayed: boolean;
  clientCompany: string;
  pickupAddress: string;
  deliveryAddress: string;
  pickupAt: string;
  expectedDeliveryAt: string;
  cargoType: string;
  revenue: number;
  totalExpenses: number;
  profit: number;
  expenseCount: number;
}>;

export type ShipmentExpense = Readonly<{
  id: string;
  category: ExpenseCategory;
  amount: number;
  expenseDate: string;
  description: string | null;
  creatorName: string;
  createdAt: string;
  updatedAt: string;
}>;

export type ShipmentFinancialData = Readonly<{
  shipment: ShipmentFinancialDetail;
  expenses: readonly ShipmentExpense[];
}>;

function expenseError(message: string): ExpenseError {
  if (message.includes("expense_read_access_denied") || message.includes("expense_mutation_access_denied")) {
    return { category: "forbidden", message: "Access denied." };
  }
  if (message.includes("expense_shipment_not_found")) {
    return { category: "not_found", message: "Shipment unavailable." };
  }
  if (message.includes("expense_not_found")) {
    return { category: "not_found", message: "Expense unavailable." };
  }
  if (message.includes("expense_stale")) {
    return { category: "conflict", message: "This expense changed since you opened it. Reload and try again." };
  }
  if (message.includes("expense_validation_failed") || message.includes("invalid input value for enum expense_category")) {
    return { category: "business_rule", message: "Check the expense details and try again." };
  }
  return { category: "infrastructure", message: "Unable to manage shipment expenses right now." };
}

export async function getShipmentFinancialData(shipmentId: string): Promise<ExpenseResult<ShipmentFinancialData>> {
  const client = await createClient();
  const [detailResponse, expensesResponse] = await Promise.all([
    client.rpc("get_operations_shipment_financial_detail", { target_shipment_id: shipmentId }),
    client.rpc("list_shipment_expenses", { target_shipment_id: shipmentId }),
  ]);
  const error = detailResponse.error ?? expensesResponse.error;
  if (error || detailResponse.data === null || expensesResponse.data === null) {
    return { ok: false, error: expenseError(error?.message ?? "expense_read_unavailable") };
  }
  const detail = detailResponse.data[0];
  if (!detail) return { ok: false, error: { category: "not_found", message: "Shipment unavailable." } };

  return {
    ok: true,
    data: {
      shipment: {
        id: detail.id,
        trackingNumber: detail.tracking_number,
        status: detail.shipment_status,
        delayed: detail.delayed,
        clientCompany: detail.client_company,
        pickupAddress: detail.pickup_address,
        deliveryAddress: detail.delivery_address,
        pickupAt: detail.pickup_at,
        expectedDeliveryAt: detail.expected_delivery_at,
        cargoType: detail.cargo_type,
        revenue: Number(detail.revenue),
        totalExpenses: Number(detail.total_expenses),
        profit: Number(detail.profit),
        expenseCount: Number(detail.expense_count),
      },
      expenses: expensesResponse.data.map((expense) => ({
        id: expense.id,
        category: expense.category,
        amount: Number(expense.amount),
        expenseDate: expense.expense_date,
        description: expense.description,
        creatorName: expense.creator_name,
        createdAt: expense.created_at,
        updatedAt: expense.updated_at,
      })),
    },
  };
}

const mutationArgs = (input: ExpenseCreateInput | ExpenseEditInput) => ({
  input_category: input.category,
  input_amount: input.amount,
  input_expense_date: input.expenseDate,
  input_description: input.description ?? undefined,
});

export async function createShipmentExpense(input: ExpenseCreateInput): Promise<ExpenseResult<{ id: string; updatedAt: string }>> {
  const client = await createClient();
  const { data, error } = await client.rpc("create_shipment_expense", {
    target_shipment_id: input.shipmentId,
    ...mutationArgs(input),
  });
  if (error) return { ok: false, error: expenseError(error.message) };
  const row = data[0];
  return row
    ? { ok: true, data: { id: row.id, updatedAt: row.updated_at } }
    : { ok: false, error: { category: "infrastructure", message: "Unable to create expense." } };
}

export async function updateShipmentExpense(input: ExpenseEditInput): Promise<ExpenseResult<"updated" | "noop">> {
  const client = await createClient();
  const { data, error } = await client.rpc("update_shipment_expense", {
    target_expense_id: input.expenseId,
    target_shipment_id: input.shipmentId,
    expected_updated_at: input.expectedUpdatedAt,
    ...mutationArgs(input),
  });
  if (error) return { ok: false, error: expenseError(error.message) };
  const row = data[0];
  return row
    ? { ok: true, data: row.mutation_result === "noop" ? "noop" : "updated" }
    : { ok: false, error: { category: "infrastructure", message: "Unable to update expense." } };
}
