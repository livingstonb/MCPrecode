classdef TableFinal_Experiments < tables.TableGen
	properties
		default_fname = '';
		included_names = {};
	end

	methods
		function obj = TableFinal_Experiments(...
			params, results, table_num, included_names,...
			use_all)
            if nargin < 5
                use_all = false;
            end

            frequencies = [1, 4];
			obj = obj@tables.TableGen(...
				params, results, frequencies, use_all);

			obj.included_names = included_names;
			obj.filter_experiments(params, use_all);
			obj.default_fname = sprintf(...
            	'Table%d_quarterly_models.csv', table_num);
		end

		function output_table = create(obj, params, results,...
			decomps_baseline)
			output_table = table();
			if isempty(obj.selected_cases)
			    return;
			end

			for ip = obj.selected_cases
				p = params(ip);
				result_structure = results(ip).direct;

				new_column = tables.OtherPanels.intro_panel(...
					result_structure, p);

				% Decompositions w.r.t baseline
				decomp = decomps_baseline(ip);

				absolute = true;
				panel_prefix = 'Panel A';
				temp = tables.DecompComparisonPanels.decomp_wrt_baseline(...
					decomp, p, 5, absolute, panel_prefix);
				new_column = [new_column; temp];

				absolute = false;
				panel_prefix = 'Panel B';
				temp = tables.DecompComparisonPanels.decomp_wrt_baseline(...
					decomp, p, 5, absolute, panel_prefix);
				new_column = [new_column; temp];

				column_label = sprintf('Specification%d', p.index);
				new_column.Properties.VariableNames = {column_label};
				output_table = [output_table, new_column];
			end

			obj.output = output_table;
		end
	end
end