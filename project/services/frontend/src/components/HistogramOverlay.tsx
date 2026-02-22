import React from 'react';
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid } from 'recharts';
import { X } from 'lucide-react';
import { HistogramPoint } from '../types';

interface Props {
  data: HistogramPoint[];
  title: string;
  onClose: () => void;
}

export const HistogramOverlay: React.FC<Props> = ({ data, title, onClose }) => (
  <div className="absolute bottom-8 left-1/2 -translate-x-1/2 w-[90%] max-w-5xl bg-white p-6 rounded-xl shadow-2xl z-[1001] border animate-in fade-in slide-in-from-bottom-4">
    <div className="flex justify-between items-center mb-6">
      <h2 className="text-xl font-bold text-slate-800">{title}</h2>
      <button onClick={onClose} className="p-1 hover:bg-gray-100 rounded-full transition-colors">
        <X size={24} />
      </button>
    </div>
    <div className="h-72">
      <ResponsiveContainer width="100%" height="100%">
        <BarChart data={data}>
          <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#f0f0f0" />
          <XAxis dataKey="name" fontSize={10} angle={-35} textAnchor="end" height={70} interval={0} />
          <YAxis fontSize={12} />
          <Tooltip cursor={{ fill: '#f8fafc' }} />
          <Bar dataKey="count" fill="#2563eb" radius={[4, 4, 0, 0]} />
        </BarChart>
      </ResponsiveContainer>
    </div>
  </div>
);