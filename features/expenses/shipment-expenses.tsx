"use client";

import { useState } from "react";
import { CircleDollarSign, Plus } from "lucide-react";

import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { EmptyState } from "@/components/ui/empty-state";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { TableCard } from "@/components/ui/table-card";
import { TableScrollArea } from "@/components/ui/table-scroll-area";
import { ExpenseForm } from "@/features/expenses/expense-form";
import { EXPENSE_CATEGORY_LABELS } from "@/features/expenses/expense-schema";
import type { ShipmentExpense } from "@/lib/dal/expenses";

const currency = new Intl.NumberFormat("en-IE", { style: "currency", currency: "EUR" });
const date = new Intl.DateTimeFormat("en-GB", { dateStyle: "medium", timeZone: "Europe/Belgrade" });

function ExpenseDialog({ shipmentId, expense }: Readonly<{ shipmentId: string; expense?: ShipmentExpense }>) {
  const [open, setOpen] = useState(false);
  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        {expense ? (
          <Button variant="ghost" className="min-h-11 md:min-h-10" focusSurface="card">Edit</Button>
        ) : (
          <Button leftIcon={Plus} className="min-h-11 w-full sm:w-auto" focusSurface="card">Add expense</Button>
        )}
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{expense ? "Edit expense" : "Add expense"}</DialogTitle>
          <DialogDescription>
            {expense ? "Update this retained Shipment expense." : "Record an authorized expense for this Shipment."}
          </DialogDescription>
        </DialogHeader>
        <div className="mt-4">
          <ExpenseForm key={`${expense?.id ?? "new"}-${open}`} shipmentId={shipmentId} expense={expense} onCancel={() => setOpen(false)} />
        </div>
      </DialogContent>
    </Dialog>
  );
}

export function ShipmentExpenses({ shipmentId, expenses }: Readonly<{
  shipmentId: string;
  expenses: readonly ShipmentExpense[];
}>) {
  if (expenses.length === 0) {
    return (
      <EmptyState
        icon={CircleDollarSign}
        title="No expenses recorded"
        description="Add the first retained expense for this Shipment."
        action={<ExpenseDialog shipmentId={shipmentId} />}
      />
    );
  }

  return (
    <TableCard
      title="Shipment expenses"
      description={`${expenses.length} ${expenses.length === 1 ? "expense" : "expenses"}`}
      toolbar={<div className="flex justify-end"><ExpenseDialog shipmentId={shipmentId} /></div>}
    >
      <TableScrollArea aria-label="Shipment expenses table">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Date</TableHead>
              <TableHead>Category</TableHead>
              <TableHead>Description</TableHead>
              <TableHead>Created by</TableHead>
              <TableHead>Amount</TableHead>
              <TableHead>Actions</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {expenses.map((expense) => (
              <TableRow key={expense.id}>
                <TableCell><time dateTime={expense.expenseDate}>{date.format(new Date(`${expense.expenseDate}T12:00:00Z`))}</time></TableCell>
                <TableCell>{EXPENSE_CATEGORY_LABELS[expense.category]}</TableCell>
                <TableCell className="max-w-xs whitespace-normal break-words">{expense.description ?? "—"}</TableCell>
                <TableCell>{expense.creatorName}</TableCell>
                <TableCell className="font-medium">{currency.format(expense.amount)}</TableCell>
                <TableCell><ExpenseDialog shipmentId={shipmentId} expense={expense} /></TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </TableScrollArea>
    </TableCard>
  );
}
