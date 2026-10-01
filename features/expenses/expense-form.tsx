"use client";

import { useActionState, useEffect } from "react";
import { useRouter } from "next/navigation";

import { createExpenseAction, editExpenseAction, type ExpenseActionState } from "@/app/(operations)/operations/shipments/[shipmentId]/actions";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select } from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import { EXPENSE_CATEGORIES, EXPENSE_CATEGORY_LABELS } from "@/features/expenses/expense-schema";
import type { ShipmentExpense } from "@/lib/dal/expenses";

const INITIAL_STATE: ExpenseActionState = {
  status: "idle",
  message: null,
  fieldErrors: {},
  correlationId: null,
};

const AUTH_DESTINATIONS = {
  unauthenticated: "/login",
  inactive_profile: "/account-inactive",
  missing_profile: "/account-error",
  forbidden: "/forbidden",
} as const;

export function ExpenseForm({ shipmentId, expense, onCancel }: Readonly<{
  shipmentId: string;
  expense?: ShipmentExpense;
  onCancel: () => void;
}>) {
  const router = useRouter();
  const [state, action, pending] = useActionState(expense ? editExpenseAction : createExpenseAction, INITIAL_STATE);
  useEffect(() => {
    if (state.status in AUTH_DESTINATIONS) {
      router.replace(AUTH_DESTINATIONS[state.status as keyof typeof AUTH_DESTINATIONS]);
    }
  }, [router, state.status]);
  const error = (field: string) => state.fieldErrors[field]?.[0];

  return (
    <form action={action} className="flex flex-col gap-4" noValidate>
      <input type="hidden" name="shipmentId" value={shipmentId} />
      {expense ? (
        <>
          <input type="hidden" name="expenseId" value={expense.id} />
          <input type="hidden" name="expectedUpdatedAt" value={expense.updatedAt} />
        </>
      ) : null}
      <div className="grid gap-4 sm:grid-cols-2">
        <div className="flex flex-col gap-2">
          <label htmlFor={`expense-category-${expense?.id ?? "new"}`} className="text-label text-foreground">Category</label>
          <Select
            id={`expense-category-${expense?.id ?? "new"}`}
            name="category"
            defaultValue={expense?.category ?? ""}
            required
            disabled={pending}
            invalid={Boolean(error("category"))}
            aria-describedby={error("category") ? `expense-category-${expense?.id ?? "new"}-error` : undefined}
            className="min-h-11 md:min-h-10"
            focusSurface="card"
          >
            <option value="" disabled>Select a category</option>
            {EXPENSE_CATEGORIES.map((category) => <option key={category} value={category}>{EXPENSE_CATEGORY_LABELS[category]}</option>)}
          </Select>
          {error("category") ? <p id={`expense-category-${expense?.id ?? "new"}-error`} className="text-small text-danger">{error("category")}</p> : null}
        </div>
        <div className="flex flex-col gap-2">
          <label htmlFor={`expense-amount-${expense?.id ?? "new"}`} className="text-label text-foreground">Amount (EUR)</label>
          <Input
            id={`expense-amount-${expense?.id ?? "new"}`}
            name="amount"
            type="number"
            min="0.01"
            max="9999999999.99"
            step="0.01"
            defaultValue={expense?.amount ?? ""}
            required
            disabled={pending}
            invalid={Boolean(error("amount"))}
            aria-describedby={error("amount") ? `expense-amount-${expense?.id ?? "new"}-error` : undefined}
            className="min-h-11 md:min-h-10"
            focusSurface="card"
          />
          {error("amount") ? <p id={`expense-amount-${expense?.id ?? "new"}-error`} className="text-small text-danger">{error("amount")}</p> : null}
        </div>
      </div>
      <div className="flex flex-col gap-2">
        <label htmlFor={`expense-date-${expense?.id ?? "new"}`} className="text-label text-foreground">Expense date</label>
        <Input
          id={`expense-date-${expense?.id ?? "new"}`}
          name="expenseDate"
          type="date"
          defaultValue={expense?.expenseDate ?? ""}
          required
          disabled={pending}
          invalid={Boolean(error("expenseDate"))}
          aria-describedby={error("expenseDate") ? `expense-date-${expense?.id ?? "new"}-error` : undefined}
          className="min-h-11 md:min-h-10"
          focusSurface="card"
        />
        {error("expenseDate") ? <p id={`expense-date-${expense?.id ?? "new"}-error`} className="text-small text-danger">{error("expenseDate")}</p> : null}
      </div>
      <div className="flex flex-col gap-2">
        <label htmlFor={`expense-description-${expense?.id ?? "new"}`} className="text-label text-foreground">Description <span className="text-small text-muted">(optional)</span></label>
        <Textarea
          id={`expense-description-${expense?.id ?? "new"}`}
          name="description"
          defaultValue={expense?.description ?? ""}
          disabled={pending}
          invalid={Boolean(error("description"))}
          aria-describedby={error("description") ? `expense-description-${expense?.id ?? "new"}-error` : undefined}
          focusSurface="card"
        />
        {error("description") ? <p id={`expense-description-${expense?.id ?? "new"}-error`} className="text-small text-danger">{error("description")}</p> : null}
      </div>
      {state.message ? (
        <p role={state.status === "success" ? "status" : "alert"} aria-live="polite" className={state.status === "success" ? "text-small text-success" : "text-small text-danger"}>
          {state.message}{state.status === "infrastructure" && state.correlationId ? ` Reference: ${state.correlationId}` : ""}
        </p>
      ) : null}
      <div className="flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
        <Button type="button" variant="outline" className="min-h-11 w-full sm:w-auto" disabled={pending} focusSurface="card" onClick={onCancel}>Cancel</Button>
        <Button type="submit" className="min-h-11 w-full sm:w-auto" loading={pending} disabled={pending} focusSurface="card">{expense ? "Save changes" : "Add expense"}</Button>
      </div>
    </form>
  );
}
