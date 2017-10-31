classdef dataLiberator < handle

properties
	handles
	file_name
	path_name
	image_data

	XLim
	YLim
	XScale
	YScale

	puppeteer_object@puppeteer

	fun@function_handle
	parameter_names@cell

	data_pts
end % end props

methods
	function self = dataLiberator(path_to_file)
		self.handles.fig = figure('outerposition',[300 300 1200 1200],'PaperUnits','points','PaperSize',[1200 1200],'WindowButtonDownFcn',@self.mouseCallback); hold on
		self.handles.image_ax = gca;
		self.handles.image_ax.Position = [0 0 1 1];
		axis(self.handles.image_ax,'off');
		if nargin < 1
			[self.file_name, self.path_name] = uigetfile('*');
			self.image_data = flipud(imread([self.path_name self.file_name]));
		else
			[self.path_name,file_name,file_ext] = fileparts(path_to_file);
			self.file_name = [file_name file_ext];
			self.image_data = flipud(imread(path_to_file));
		end
		

		self.handles.im = imagesc(self.handles.image_ax,self.image_data);
		%axis equal

		self.handles.plot_ax = axes;
		self.handles.plot_ax.Color = [0 0 0 0];
		self.handles.plot_ax.Position = [.1 .1 .8 .8];
		prettyFig();

		self.handles.fun_plot  = [];

		% make a toggle button to add points 
		self.handles.add_button = uicontrol(self.handles.fig,'units','normalized','Position',[.01 .95 .12 .05],'Style','togglebutton','String','Add point','Enable','on');

		self.handles.data_pts = plot(self.handles.plot_ax,NaN,NaN,'ro','LineStyle','none','Color',[1 0 0],'MarkerSize',20,'LineWidth',5);
		self.handles.plot_ax.Color = [0 0 0 0];

		% add a manipulate button
		self.handles.manipualte_button = uicontrol(self.handles.fig,'units','normalized','Position',[.15 .95 .12 .05],'Style','pushbutton','String','Manipulate','Enable','on','Callback',@self.manipulate);

	end % end constructor 


	function mouseCallback(self,src,event)
		if ~self.handles.add_button.Value
			return
		end

		p = get(self.handles.plot_ax,'CurrentPoint');
		p = p(1,1:2);
		
		% add to list of data points 
		self.data_pts = [self.data_pts; p];

		% show the data points
		self.handles.data_pts.XData = self.data_pts(:,1);
		self.handles.data_pts.YData = self.data_pts(:,2);

	end


	function set.XLim(self,value)
		self.XLim = value;
		self.handles.plot_ax.XLim = value;
	end % end set XLim

	function set.YLim(self,value)
		self.YLim = value;
		self.handles.plot_ax.YLim = value;
	end % end set YLim


	function puppeteerCallback(self,parameters)		
		% move image and axes if needed

		if iscell(parameters)
			im_pos = parameters{1};
		else
			im_pos = parameters;
		end

		ay = floor(im_pos.y_start);
		ax = floor(im_pos.x_start);
		new_im = self.image_data(ay:end,ax:end,:);
		self.handles.im.CData = new_im;
		self.handles.ax.XLim = [ax size(self.image_data,2)-ax];
		self.handles.ax.YLim = [ay size(self.image_data,1)-ay];
		self.handles.plot_ax.Position(4) = im_pos.y_stop;
		self.handles.plot_ax.Position(3) = im_pos.x_stop;

		if ~iscell(parameters)
			return
		end

		% now manipulate the plot
		fun_params = parameters{2};
		F = {};
		for i = 1:length(self.parameter_names)
			F{i+1} = fun_params.(self.parameter_names{i});
		end
		if isempty(self.handles.fun_plot)
			% first time
			x = linspace(self.XLim(1),self.XLim(2),1e3);
			F{1} = x;
			y = self.fun(F{:});
			self.handles.fun_plot = plot(self.handles.plot_ax,x,y,'r','LineWidth',3);
		else
			x = linspace(self.XLim(1),self.XLim(2),1e3);
			F{1} = x;
			y = self.fun(F{:});
			self.handles.fun_plot.YData = y;

		end

		% override matlab's stupid overrides
		self.handles.plot_ax.Color = [0 0 0 0];
		self.handles.plot_ax.XLim = self.XLim;
		self.handles.plot_ax.YLim = self.YLim;

	end

	function manipulate(self,~,~)

		% create a puppeteer instance
		S.x_start = 1;
		S.y_start = 1;
		S.x_stop = self.handles.plot_ax.Position(3);
		S.y_stop = self.handles.plot_ax.Position(4);

		ub.x_start = size(self.image_data,2);
		ub.y_start = size(self.image_data,1);
		ub.x_stop = 1;
		ub.y_stop = 1;

		lb.x_start = 1;
		lb.y_start = 1;
		lb.x_stop = 0;
		lb.y_stop = 0;

		if ~isempty(self.parameter_names)
			S2 = [];
			lb2 = [];
			ub2 = [];
			for i = 1:length(self.parameter_names)
				S2.(self.parameter_names{i}) = 1;
				lb2.(self.parameter_names{i}) = 0;
				ub2.(self.parameter_names{i}) = 2;
			end

			S = {S; S2};
			lb = {lb; lb2};
			ub = {ub; ub2};
		end


		self.puppeteer_object = puppeteer(S,lb,ub);
		attachFigure(self.puppeteer_object,self.handles.fig);

		% wire up the callbacks
		self.puppeteer_object.callback_function = @self.puppeteerCallback;
	end

	function addFun(self,fun_handle,parameters)
		assert(isa(fun_handle,'function_handle'),'expected a function handle')
		self.fun = fun_handle;
		self.parameter_names = parameters;

	end % end addFun

end % end methods 

end % enb classdef 